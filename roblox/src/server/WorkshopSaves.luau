local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Preferences = require(ReplicatedStorage.GarageDay.Preferences)
local Service = require(ReplicatedStorage.GarageDay.Service)
local SaveSlot = require(script.Parent.SaveSlot)

local WorkshopSaves = {}
WorkshopSaves.__index = WorkshopSaves

local function backend()
	if RunService:IsStudio() and game.GameId == 0 then
		local bridge = ServerStorage:WaitForChild("GarageDayLocalSave", 3)
		if not bridge then return nil end
		return {
			read = function(key)
				local value = bridge:Invoke("read", key)
				return value
			end,
			update = function(key, transform)
				for _ = 1, 3 do
					local previous, version = bridge:Invoke("read", key)
					local value = transform(previous)
					if value == nil then return nil end
					if bridge:Invoke("write", key, version, value) then return value end
				end
				error("Atelier local occupé")
			end,
		}
	end
	local store = DataStoreService:GetDataStore("GarageDaySavesV1", if RunService:IsStudio() then "Studio" else "Live")
	local readOptions = Instance.new("DataStoreGetOptions")
	readOptions.UseCache = false
	return {
		read = function(key) return store:GetAsync(key, readOptions) end,
		update = function(key, transform) return store:UpdateAsync(key, transform) end,
	}
end

local function load(slot)
	for _, delay in { 0, 0.6, 1.4 } do
		if delay > 0 then task.wait(delay) end
		local value = slot:load()
		if slot.status ~= "retry" then return value end
	end
	slot.status = "unavailable"
	return nil
end

function WorkshopSaves.new(state, session)
	local self = setmetatable({ state = state, session = session, settings = {} }, WorkshopSaves)
	session:SetAttribute("SaveState", "loading")
	self.backend = backend()
	return self
end

function WorkshopSaves:slot(key)
	return SaveSlot.new(self.backend, key, function() return HttpService:GenerateGUID(false) end)
end

function WorkshopSaves:updateStatus(slot)
	if slot == self.workshop then
		self.session:SetAttribute("SaveState", slot.status)
	elseif slot.player and slot.player.Parent then
		slot.player:SetAttribute("OptionsSaveState", slot.status)
	end
end

function WorkshopSaves:restore(player)
	local slot = self:slot("workshop_" .. player.UserId)
	self.workshop = slot
	self.session:SetAttribute("SaveOwner", player.DisplayName)
	local previous = load(slot)
	if previous and not Service.restore(self.state, previous) then
		slot.loaded = false
		slot.status = "unsupported"
	end
	self:updateStatus(slot)
end

function WorkshopSaves:watch(player)
	local slot = self:slot("options_" .. player.UserId)
	slot.player = player
	self.settings[player] = slot
	player:SetAttribute("MouseSensitivity", Preferences.defaultSensitivity)
	task.spawn(function()
		local saved = load(slot)
		if self.settings[player] ~= slot then return end
		local sensitivity = saved and Preferences.sensitivity(saved.sensitivity)
		player:SetAttribute("MouseSensitivity", sensitivity or Preferences.defaultSensitivity)
		player:SetAttribute("SensitivityReady", true)
		self:updateStatus(slot)
	end)
end

function WorkshopSaves:schedule(slot)
	if slot.scheduled then return end
	slot.scheduled = true
	task.delay(0.8, function()
		slot.scheduled = false
		self:flush(slot)
	end)
end

function WorkshopSaves:changeSensitivity(player, value)
	local slot = self.settings[player]
	local sensitivity = Preferences.sensitivity(value)
	if not slot or not sensitivity or not player:GetAttribute("SensitivityReady")
		or player:GetAttribute("MouseSensitivity") == sensitivity then return end
	player:SetAttribute("MouseSensitivity", sensitivity)
	if slot:queue({ sensitivity = sensitivity }) then self:schedule(slot) end
end

function WorkshopSaves:checkpoint()
	local slot = self.workshop
	if slot and slot.loaded and self.state.day > 0 and slot:queue(Service.snapshot(self.state)) then self:schedule(slot) end
end

function WorkshopSaves:flush(slot)
	if not slot or not slot:hasPending() or slot.busy then return end
	if slot == self.workshop then self.session:SetAttribute("SaveState", "saving") end
	slot:flush()
	self:updateStatus(slot)
	if slot.status == "saved" and slot:hasPending() then self:schedule(slot) end
end

function WorkshopSaves:drain(slot)
	local expires = os.clock() + 12
	while slot and slot:hasPending() and os.clock() < expires do
		self:flush(slot)
		if slot:hasPending() then task.wait(if slot.busy then 0.10 else 1.0) end
	end
end

function WorkshopSaves:leaving(player)
	local slot = self.settings[player]
	if not slot then return end
	self:drain(slot)
	if self.settings[player] == slot then self.settings[player] = nil end
end

function WorkshopSaves:retryPending()
	self:flush(self.workshop)
	for _, slot in self.settings do
		if slot:hasPending() then task.spawn(function() self:flush(slot) end) end
	end
end

function WorkshopSaves:bindToClose()
	game:BindToClose(function()
		local pending = 0
		for _, slot in self.settings do
			pending += 1
			task.spawn(function() self:drain(slot) pending -= 1 end)
		end
		self:drain(self.workshop)
		local expires = os.clock() + 12
		while pending > 0 and os.clock() < expires do task.wait(0.1) end
	end)
	task.spawn(function()
		while self.session.Parent do
			task.wait(14)
			self:retryPending()
		end
	end)
end

return WorkshopSaves

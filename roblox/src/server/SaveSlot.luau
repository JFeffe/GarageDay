--!strict

local SaveSlot = {}
SaveSlot.__index = SaveSlot

type Snapshot = { [string]: any }
type Record = { version: number, stamp: string, data: Snapshot }
type Backend = { read: (string) -> any, update: (string, (any) -> Record?) -> any }
type Fields = {
	backend: Backend?, key: string, makeStamp: () -> string, status: string,
	loaded: boolean, busy: boolean, stamp: string?, pending: Record?, latest: Snapshot?,
}
type Slot = typeof(setmetatable({} :: Fields, SaveSlot))

local function valid(record: any): boolean
	return type(record) == "table" and record.version == 1 and type(record.stamp) == "string" and type(record.data) == "table"
end

function SaveSlot.new(backend: Backend?, key: string, makeStamp: () -> string): Slot
	return setmetatable({
		backend = backend, key = key, makeStamp = makeStamp, status = "loading", loaded = false, busy = false,
		stamp = nil, pending = nil, latest = nil,
	} :: Fields, SaveSlot)
end

function SaveSlot.load(self: Slot): any
	if not self.backend then
		self.status = "unavailable"
		return nil
	end
	local ok, record = pcall(self.backend.read, self.key)
	if not ok then
		self.status = "retry"
		return nil
	end
	if record ~= nil and not valid(record) then
		self.status = "unsupported"
		return nil
	end
	self.status = if record then "saved" else "ready"
	self.loaded = true
	self.stamp = record and record.stamp
	return record and record.data
end

function SaveSlot.queue(self: Slot, data: Snapshot): boolean
	if not self.loaded then return false end
	self.latest = data
	return true
end

function SaveSlot.hasPending(self: Slot): boolean
	return self.loaded and (self.latest ~= nil or self.pending ~= nil)
end

function SaveSlot.flush(self: Slot)
	local backend = self.backend
	if not backend or not self.loaded or self.busy then return end
	local pending = self.pending
	if not pending then
		local snapshot = self.latest
		if not snapshot then return end
		pending = { version = 1, stamp = self.makeStamp(), data = snapshot }
		self.pending = pending
		self.latest = nil
	end
	local expected = self.stamp
	local candidate: Record = assert(pending)
	self.busy = true
	self.status = "saving"
	local ok, record = pcall(backend.update, self.key, function(current: any): Record?
		if current ~= nil then
			if not valid(current) then return nil end
			-- A retry can follow a successfully committed write whose response was lost.
			if current.stamp == candidate.stamp then return current end
		end
		if (current and current.stamp) ~= expected then return nil end
		return candidate
	end)
	self.busy = false
	if not ok then
		self.status = "retry"
	elseif record == nil then
		self.loaded = false
		self.status = "conflict"
		self.pending, self.latest = nil, nil
	else
		self.stamp = candidate.stamp
		self.pending = nil
		self.status = "saved"
	end
end

return SaveSlot

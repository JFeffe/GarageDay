local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")

local MeshLibrary = {}

local function build(asset)
	local info = require(asset)
	local chunks = table.create(info.chunks)
	for i = 1, info.chunks do
		chunks[i] = require(asset["Chunk" .. i])
	end
	local data = EncodingService:Base64Decode(buffer.fromstring(table.concat(chunks)))
	local vertexCount = buffer.readu16(data, 0)
	local faceCount = buffer.readu16(data, 2)
	local mesh = assert(AssetService:CreateEditableMesh(), "EditableMesh unavailable")
	local vertices = table.create(vertexCount)
	local colors = {}
	local cursor = 4
	for i = 1, vertexCount do
		vertices[i] = mesh:AddVertex(Vector3.new(
			buffer.readi16(data, cursor), buffer.readi16(data, cursor + 2), buffer.readi16(data, cursor + 4)
		) / 256)
		cursor += 6
	end
	for _ = 1, faceCount do
		local face = mesh:AddTriangle(vertices[1 + buffer.readu16(data, cursor)],
			vertices[1 + buffer.readu16(data, cursor + 2)], vertices[1 + buffer.readu16(data, cursor + 4)])
		local r, g, b = buffer.readu8(data, cursor + 6), buffer.readu8(data, cursor + 7), buffer.readu8(data, cursor + 8)
		local key = r * 65536 + g * 256 + b
		if not colors[key] then
			colors[key] = mesh:AddColor(Color3.fromRGB(r, g, b), 1)
		end
		local color = colors[key]
		mesh:SetFaceColors(face, { color, color, color })
		cursor += 9
	end

	-- Bake once on the server so the same mesh content can render on every client.
	local result, content = AssetService:CreateDataModelContentAsync(Content.fromObject(mesh))
	mesh:Destroy()
	assert(result == Enum.CreateContentResult.Success, tostring(result))
	local part = AssetService:CreateMeshPartAsync(content, { CollisionFidelity = Enum.CollisionFidelity.Box })
	part.Name = asset.Name
	part.CFrame = CFrame.new(Vector3.new(table.unpack(info.center)))
	part.Size = Vector3.new(table.unpack(info.size))
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

function MeshLibrary.load()
	local models = {}
	for _, asset in script.Parent.MeshData:GetChildren() do
		local ok, mesh = pcall(build, asset)
		if ok then
			models[asset.Name] = mesh
		else
			warn("Garage Day · " .. asset.Name .. " · " .. tostring(mesh))
		end
	end
	return models
end

return MeshLibrary

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Repair = require(ReplicatedStorage:WaitForChild("GarageDay"):WaitForChild("Repair"))
local playerGui = player:WaitForChild("PlayerGui")
player.CameraMode = Enum.CameraMode.LockFirstPerson
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local cream = Color3.fromRGB(255, 239, 210)
local mint = Color3.fromRGB(161, 212, 197)
local gold = Color3.fromRGB(249, 200, 113)
local ink = Color3.fromRGB(19, 37, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "GarageDay"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -14, 0, 10)
panel.Size = UDim2.fromScale(0.46, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = ink
panel.BackgroundTransparency = 0.08
panel.Parent = gui

local bounds = Instance.new("UISizeConstraint")
bounds.MinSize = Vector2.new(224, 0)
bounds.MaxSize = Vector2.new(318, 1000)
bounds.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(75, 114, 113)
outline.Transparency = 0.4
outline.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 11)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.Parent = panel
local stack = Instance.new("UIListLayout")
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 5)
stack.Parent = panel

local function label(order, text, size, color, bold)
	local item = Instance.new("TextLabel")
	item.LayoutOrder = order
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundTransparency = 1
	item.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	item.TextColor3 = color
	item.TextSize = size
	item.Text = text
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = panel
	return item
end

label(1, "LE PETIT ATELIER", 12, mint, true)
local action = label(2, "Préparation du garage…", 19, cream, true)
local hint = label(3, "", 13, cream, false)
local held = label(5, "", 12, mint, false)

local rail = Instance.new("Frame")
rail.LayoutOrder = 4
rail.Size = UDim2.new(1, 0, 0, 3)
rail.BackgroundColor3 = Color3.fromRGB(58, 82, 84)
rail.BorderSizePixel = 0
rail.Parent = panel
local progress = Instance.new("Frame")
progress.Size = UDim2.fromScale(0, 1)
progress.BackgroundColor3 = gold
progress.BorderSizePixel = 0
progress.Parent = rail

local reticleGui = Instance.new("ScreenGui")
reticleGui.Name = "ViseurGarageDay"
reticleGui.ResetOnSpawn = false
reticleGui.ScreenInsets = Enum.ScreenInsets.None
reticleGui.Parent = playerGui
local reticle = Instance.new("Frame")
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(5, 5)
reticle.BackgroundColor3 = cream
reticle.BorderSizePixel = 0
reticle.Parent = reticleGui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(1, 0)
round.Parent = reticle
local edge = Instance.new("UIStroke")
edge.Color = ink
edge.Parent = reticle

local function updateReticle()
	reticleGui.Enabled = UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
end
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateReticle)
updateReticle()

local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local function refresh()
	local index = session:GetAttribute("Step") or 1
	local step = Repair.steps[index]
	local wrenchOwner = session:GetAttribute("WrenchOwner") or 0
	local padsOwner = session:GetAttribute("PadsOwner") or 0
	local ownWrench = wrenchOwner == player.UserId
	local ownPads = padsOwner == player.UserId
	action.Text = step.title
	action.TextColor3 = if index == #Repair.steps then mint else cream
	hint.Text = step.hint
	if session:GetAttribute("LiftMoving") then
		action.Text = if step.action == "raise" then "Le pont monte" else "Le pont descend"
		hint.Text = if step.action == "raise" then "Tu peux préparer les outils." else "Attends l’arrêt du pont."
	elseif step.item == "wrenchOwner" then
		if ownWrench then
			hint.Text = "Vise la roue avant gauche."
		elseif wrenchOwner ~= 0 then
			hint.Text = "Ton collègue a la clé à choc."
		else
			hint.Text = "Prends la clé à choc à l’établi rouge."
		end
	elseif step.item == "padsOwner" then
		if ownPads then
			hint.Text = "Vise le disque derrière la roue."
		elseif padsOwner ~= 0 then
			hint.Text = "Ton collègue a les plaquettes."
		end
	end
	local items = {}
	if ownWrench then table.insert(items, "Clé à choc") end
	if ownPads then table.insert(items, "Plaquettes") end
	held.Text = if #items > 0 then "En main · " .. table.concat(items, " + ") else "Mains libres"
	progress.Size = UDim2.fromScale((index - 1) / (#Repair.steps - 1), 1)
end
session.AttributeChanged:Connect(refresh)
refresh()

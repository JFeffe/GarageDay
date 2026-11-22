--!strict

export type State = {
	step: number,
	wrenchOwner: number,
	padsOwner: number,
	moving: boolean,
}

type Step = {
	action: string,
	title: string,
	hint: string,
	target: string,
	hold: number,
	item: ("wrenchOwner" | "padsOwner")?,
}

local Repair = {}

Repair.steps = table.freeze({
	{ action = "raise", title = "Lever le pont", hint = "Vise le levier jaune.", target = "Lever", hold = 0 },
	{ action = "loosen", title = "Desserrer la roue", hint = "Prends la clé à choc puis vise la roue avant gauche.", target = "Wheel", hold = 0.65, item = "wrenchOwner" },
	{ action = "remove", title = "Déposer la roue", hint = "Retire la roue pour accéder au frein.", target = "Wheel", hold = 0.45 },
	{ action = "install", title = "Poser les plaquettes", hint = "Prends les plaquettes sur l’étagère puis vise le disque.", target = "Wheel", hold = 0.85, item = "padsOwner" },
	{ action = "mount", title = "Remonter la roue", hint = "Replace la roue sur son moyeu.", target = "Wheel", hold = 0.45 },
	{ action = "tighten", title = "Serrer la roue", hint = "Serre la roue avec la clé à choc.", target = "Wheel", hold = 0.65, item = "wrenchOwner" },
	{ action = "lower", title = "Abaisser le pont", hint = "Retourne au levier pour terminer l’intervention.", target = "Lever", hold = 0 },
	{ action = "replay", title = "Intervention terminée", hint = "Reviens au levier pour recommencer.", target = "Lever", hold = 0.65 },
} :: { Step })

local installStep = 4

function Repair.new(): State
	return { step = 1, wrenchOwner = 0, padsOwner = 0, moving = false }
end

function Repair.canTakePads(state: State): boolean
	return state.step <= installStep and state.padsOwner == 0
end

function Repair.act(state: State, playerId: number, action: string): boolean
	if action == "takeWrench" and state.wrenchOwner == 0 and state.step < #Repair.steps then
		state.wrenchOwner = playerId
		return true
	elseif action == "returnWrench" and state.wrenchOwner == playerId then
		state.wrenchOwner = 0
		return true
	elseif action == "takePads" and Repair.canTakePads(state) then
		state.padsOwner = playerId
		return true
	end

	local step = Repair.steps[state.step]
	local itemOwner = if step.item == "padsOwner" then state.padsOwner else state.wrenchOwner
	if state.moving or action ~= step.action or (step.item and itemOwner ~= playerId) then
		return false
	end

	if action == "raise" or action == "lower" then
		state.moving = true
	elseif action == "replay" then
		state.step = 1
		state.wrenchOwner = 0
		state.padsOwner = 0
	else
		if action == "install" then
			state.padsOwner = 0
		end
		state.step += 1
	end
	return true
end

function Repair.finishLift(state: State)
	if state.moving then
		state.moving = false
		state.step += 1
	end
end

function Repair.release(state: State, playerId: number)
	if state.wrenchOwner == playerId then
		state.wrenchOwner = 0
	end
	if state.padsOwner == playerId then
		state.padsOwner = 0
	end
end

return Repair

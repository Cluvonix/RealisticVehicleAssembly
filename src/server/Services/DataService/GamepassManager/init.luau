--[[
		Manage buying gamepasses and syncing data
]]

local GamepassManager = {}

-- Services
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Reference
local GamepassList = require(script.GamepassList)
local DataManager = require(script.Parent.DataManager)

-- Prompts a gamepass purchasw withthe pass' name
function GamepassManager:PromptPurchase(player: Player, name: string)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	local passId: string = GamepassList.GetGamepassId(name)
	if passId == nil then
		return
	end

	-- Check if player owns pass from profile (gifted gamepass)
	local hasPass = profile.Data.Gamepass[passId].owned
	print(player.Name, "requests gamepass" .. name, "| owned:", hasPass)

	-- Check marketplace for ownership and update
	if hasPass == false then
		local success, message = pcall(function()
			hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
		end)

		if not success then
			warn("Error while checking if player owns gamepass:", message)
			return
		end

		if hasPass == false then
			-- Prompt gamepass purchase
			MarketplaceService:PromptGamePassPurchase(player, tonumber(passId))
		elseif hasPass == true then
			-- Re-sync all gamepass data
			GamepassManager:UpdateOwnershipData(player)
		end
	end
end

-- Award gamepass if purchase is successful
function GamepassManager:OnPromptPurchaseFinished(player: Player, gamepassIdNumber: number, wasPurchased: boolean)
	if wasPurchased == false then
		return
	end
	gamepassId = tostring(gamepassIdNumber)

	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	-- Save gamepass ownership
	profile.Data.Gamepass[gamepassId].owned = true

	-- Award gamepass function
	local awardFunction = GamepassList.Functions[gamepassId]
	if awardFunction then
		awardFunction(player)
		profile.Data.Gamepass[gamepassId].awarded = true
	else
		warn("No awardFunction for gamepass:", gamepassId)
	end
end

-- Checks and updates if player owns each gamepass
function GamepassManager:UpdateOwnershipData(player: Player)
	local profile = DataManager.Profiles[player]
	if not profile then
		return
	end

	-- Loop through all gamepasses
	for passId: string, awardFunctions in pairs(GamepassList.Functions) do
		local hasPass = profile.Data.Gamepass[passId].owned

		if hasPass == false then
			-- Check marketplace service to see if player owns pass
			local success, message = pcall(function()
				hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, tonumber(passId))
			end)

			if not success then
				warn("Error while checking if player owns gamepass:", message)
				continue
			end

			-- If player owns gamepass, save and award it
			if hasPass ~= false then
				profile.Data.Gamepass[passId].owned = true

				awardFunctions(player)
				profile.Data.Gamepass[passId].awarded = true
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(...)
	GamepassManager:OnPromptPurchaseFinished(...)
end)

-- ReplicatedStorage.RequestGamepass.OnServerEvent:Connect(function(player, name)
-- 	GamepassManager:PromptPurchase(player, name)
-- end)

return GamepassManager

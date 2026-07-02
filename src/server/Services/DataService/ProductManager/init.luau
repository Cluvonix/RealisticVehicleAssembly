local ProductManager = {}

-- Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- References
local DataManager = require(script.Parent.DataManager)
local ProductFunctions = require(script.Products)

local MAX_CACHE_SIZE = 100

-- Prompts a player to buy a Developer Product
function ProductManager.ProductPurchaseRequested(player: Player, productId: number)
	-- Sanity check on productId
	if ProductFunctions[productId] == nil then
		warn("No product function for ProductId:", productId, "| Player:", player.Name, player.UserId)
		return
	end

	-- Prompt a purchase
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- Waits Until purchaseId has been stored in the Profile before confirming ProductPurchaseDecision
local function CheckPurchaseIdAsync(profile, purchasedId, grantProductFunction): Enum.ProductPurchaseDecision
	-- Check if profile is active
	if profile:IsActive() == true then
		-- Get cache of previous purchaseIds
		local purchasedIdCache = profile.Data.PurchaseIdCache
		if purchasedIdCache == nil then
			purchasedIdCache = {}
			profile.Data.PurchaseIdCache = purchasedIdCache
		end

		-- Grant product if not previously logged
		if table.find(purchasedIdCache, purchasedId) == nil then
			-- Grant product
			local success, result = pcall(grantProductFunction)

			-- If pcall failed:
			if success == false then
				warn("Failed to grant product:", profile.Key, purchasedId, result)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			--if pcall succeded (log purchasedId to cache):

			-- Remove outdated purchaseIds
			while #purchasedIdCache >= MAX_CACHE_SIZE do
				table.remove(purchasedIdCache, 1)
			end

			table.insert(purchasedIdCache, purchasedId)
		end

		-- At this point, product has been confirmed granted
		-- Verify that the product has been logged in the DataStore
		local function isPurchasedSaved(): boolean
			local savedCache = profile.LastSavedData.PurchasedIdCache
			return if savedCache ~= nil then table.find(savedCache, purchasedId) ~= nil else false
		end

		-- Initial purchaseId saved check:
		if isPurchasedSaved() == true then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- Periodically check if the purchaseId is saved UNTIL it is, OR the profile's session ends
		while profile:IsActive() == true do
			-- Get a copy of current LastSavedData
			local lastSavedDataCopy = profile.LastSavedData

			--Manually save the profile
			profile:Save()

			--Wait until the profile has been saved
			if profile.LastSavedData == lastSavedDataCopy then
				profile.OnAfterSave:Wait()
			end

			-- Check if purchaseId has been saved
			if isPurchasedSaved() == true then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end

			-- Wait a period of time and try again
			if profile:IsActive() == true then
				task.wait(10)
			end
		end
	end

	-- Profile is not active or session ended
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

--MarketPlace callback to verify product has been granted
local function ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	-- Make sure player is in game
	if player ~= nil then
		local profile = DataManager.Profiles[player]

		-- Wait for profile to exist
		while profile == nil and player.Parent == Players do
			task.wait()
			profile = DataManager.Profiles[player]
		end

		-- Make sure profile exists
		if profile ~= nil then
			-- Sanity check on productId
			if ProductFunctions[receiptInfo.ProductId] == nil then
				warn(
					"No product function for ProductId:",
					receiptInfo.ProductId,
					"| Player:",
					player.Name,
					player.UserId
				)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			-- Grant product and return result
			local productPurchaseDecision = CheckPurchaseIdAsync(profile, receiptInfo.PurchaseId, function()
				ProductFunctions[receiptInfo.ProductId](receiptInfo, player, profile) -- calling product function
			end)

			return productPurchaseDecision
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Connect ProcessReceipt Callback
MarketplaceService.ProcessReceipt = ProcessReceipt

-- ReplicatedStorage.Request100GoldProduct.OnServerEvent:Connect(function(player: Player)
-- 	ProductManager.ProductPurchaseRequested(player, 2712254299)
-- end)

-- ReplicatedStorage.Request50GemsProduct.OnServerEvent:Connect(function(player: Player)
-- 	ProductManager.ProductPurchaseRequested(player, 3428469034)
-- end)

return ProductManager

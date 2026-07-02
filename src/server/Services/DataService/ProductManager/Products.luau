local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.Server.Services.DataService.DataManager)

return {
	-- [developer product id] = function() which awards the product
	
	-- -- Buy 100 Gold
	-- [2712254299] = function(receiptInfo, player, profile)
	-- 	DataManager:AddGold(player, 100)
	-- end,
	
	-- -- Buy 50 Gems
	-- [3428469034] = function(receiptInfo, player, profile)
	-- 	DataManager:AddGems(player, 50)
	-- end,
}
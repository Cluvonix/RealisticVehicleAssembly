--[[
		Store gamepass names, productIds, and award functions
]]

local GamepassList = {}

-- Assign a gamepass name to its Id
GamepassList.Names = {
	VIP = "1531463433",
	GoldX2 = "1531555527",
	GemsX2 = "1531269641",
}

function GamepassList.GetGamepassId(name: string)
	return GamepassList.Names[name]
end

-- Award functions for gamepasses (called once when bought)
GamepassList.Functions = {

	-- VIP
	["1531463433"] = function(player: Player)
		print("VIP Gamepass awarded!")
	end,

	--2x Gold
	["1531555527"] = function(player: Player)
		print("2x Gold gamepass awarded!")
	end,

	--2x Gems
	["1531269641"] = function(player: Player)
		print("2x Gems gamepass awarded!")
	end,
}

return GamepassList

local DataService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Utils.Network)

-- Store profiles from ProfileStore
DataService.Profiles = {}

function DataService.AddCash(player, amount: number)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Cash += amount
	player:WaitForChild("leaderstats"):WaitForChild("Cash").Value = profile.Data.Cash
	Network:FireClient(player, "UpdateCash", profile.Data.Cash)
end

return DataService

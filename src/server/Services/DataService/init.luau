local DataService = {}

function DataService.init()
	-- Services
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	-- ProfileStore

local Network = require(ReplicatedStorage.Shared.Utils.Network)
	local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

	local function GetStoreName()
		return RunService:IsStudio() and "Test" or "Live"
	end

	local DataManager = require(script.DataManager)
	local GamepassManager = require(script.GamepassManager)
	local ProductManager = require(script.ProductManager)
	local Template = require(script.Template)

	-- Access profile store
	local PlayerStore = ProfileStore.New(GetStoreName(), Template)

	-- Add leaderstats and synchronize player data
	local function Initialize(player: Player, profile: typeof(PlayerStore:StartSessionAsync()))
		-- Leaderstats
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local Cash = Instance.new("NumberValue")
		Cash.Name = "Cash"
		Cash.Value = profile.Data.Cash
		Cash.Parent = leaderstats

		-- Sync player data
		Network:FireClient(player, "UpdateCash", profile.Data.Cash)

		GamepassManager:UpdateOwnershipData(player)
	end

	local function PlayerAdded(player: Player)
		-- Start a new profile session
		local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		-- Sanity check to ensure profile exists
		if profile ~= nil then
			profile:AddUserId(player.UserId) -- GDPR compliance
			profile:Reconcile() -- Fill in missing variables from template

			-- Handles session-locking
			profile.OnSessionEnd:Connect(function()
				DataManager.Profiles[player] = nil
				player:Kick("Data error occured. Please rejoin.")
			end)

			if player.Parent == Players then
				DataManager.Profiles[player] = profile
				Initialize(player, profile)
			else
				profile:EndSession()
			end
		else
			-- Server shuts down while player is joining
			player:Kick("Data error occured. Please rejoin.")
		end
	end

	-- Early joiners
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerAdded, player)
	end
	Players.PlayerAdded:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = DataManager.Profiles[player]
		if not profile then
			return
		end
		profile:EndSession()
		DataManager.Profiles[player] = nil
	end)
end

return DataService

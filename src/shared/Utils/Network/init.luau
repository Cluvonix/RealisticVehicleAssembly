local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = require(script.Remotes)

local Network = {}

local RATE_LIMIT_TIME = 0.1
local MAX_VIOLATIONS = 50
local playerCooldowns = {}
local playerViolations = {}
local cachedRemotes = {}
local remotesFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("Network")

function Network.Init()
	if RunService:IsServer() then
		for _, remoteName in ipairs(Remotes.Remotes) do
			if not remotesFolder:FindFirstChild(remoteName) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = remoteName
				remote.Parent = remotesFolder
			end
		end

		for _, remoteName in ipairs(Remotes.RemoteFunctions) do
			if not remotesFolder:FindFirstChild(remoteName) then
				local remoteFunction = Instance.new("RemoteFunction")
				remoteFunction.Name = remoteName
				remoteFunction.Parent = remotesFolder
			end
		end

		Players.PlayerRemoving:Connect(function(player)
			playerCooldowns[player.UserId] = nil
			playerViolations[player.UserId] = nil
		end)
	end

	for _, remoteName in ipairs(Remotes.Remotes) do
		cachedRemotes[remoteName] = remotesFolder:WaitForChild(remoteName)
	end
	for _, remoteName in ipairs(Remotes.RemoteFunctions) do
		cachedRemotes[remoteName] = remotesFolder:WaitForChild(remoteName)
	end
end

function Network:FireClient(player, remoteName, ...)
	local remote = cachedRemotes[remoteName] or remotesFolder:FindFirstChild(remoteName)
	if remote then
		remote:FireClient(player, ...)
	else
		warn("RemoteEvent '" .. remoteName .. "' not found.")
	end
end

function Network:FireFunction(player, remoteName, ...)
	local remote = cachedRemotes[remoteName] or remotesFolder:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteFunction") then
		return remote:InvokeClient(player, ...)
	else
		warn("RemoteFunction '" .. remoteName .. "' not found.")
		return nil
	end
end

function Network:FireAllClients(remoteName, ...)
	local remote = cachedRemotes[remoteName] or remotesFolder:FindFirstChild(remoteName)
	if remote then
		remote:FireAllClients(...)
	else
		warn("RemoteEvent '" .. remoteName .. "' not found.")
	end
end

function Network:FireServer(remoteName, ...)
	if RunService:IsServer() then
		warn("FireServer called on the server for '" .. remoteName .. "'. Use FireClient/FireAllClients instead.")
		return
	end

	local remote = cachedRemotes[remoteName] or remotesFolder:FindFirstChild(remoteName)
	if remote then
		remote:FireServer(...)
	else
		warn("RemoteEvent '" .. remoteName .. "' not found.")
	end
end

function Network:GetRemote(remoteName)
	if cachedRemotes[remoteName] then
		return cachedRemotes[remoteName]
	end

	local remote = remotesFolder:WaitForChild(remoteName)
	if remote then
		cachedRemotes[remoteName] = remote
		return remote
	end

	warn("RemoteEvent '" .. remoteName .. "' not found.")
	return nil
end

function Network:OnServerEvent(remoteName, handler)
	if not RunService:IsServer() then
		warn("OnServerEvent called on the client for '" .. remoteName .. "'.")
		return
	end

	local remote = self:GetRemote(remoteName)
	if not remote then
		return
	end

	remote.OnServerEvent:Connect(function(player, ...)
		if self:CheckRateLimit(player, remoteName) then
			handler(player, ...)
		end
	end)
end

function Network:OnClientEvent(remoteName, handler)
	if RunService:IsServer() then
		warn("OnClientEvent called on the server for '" .. remoteName .. "'.")
		return
	end

	local remote = self:GetRemote(remoteName)
	if not remote then
		return
	end

	remote.OnClientEvent:Connect(handler)
end

function Network:CheckRateLimit(player, remoteName)
	if not RunService:IsServer() then
		return true
	end

	local userId = player.UserId

	-- Initialize cooldown table for player
	if not playerCooldowns[userId] then
		playerCooldowns[userId] = {}
	end

	if not playerViolations[userId] then
		playerViolations[userId] = 0
	end

	-- Check rate limit
	local lastCall = playerCooldowns[userId][remoteName]
	local currentTime = os.clock()

	if lastCall and (currentTime - lastCall) < RATE_LIMIT_TIME then
		playerViolations[userId] = playerViolations[userId] + 1
		warn(
			"Player "
				.. player.Name
				.. " rate limited on "
				.. remoteName
				.. " (Violation "
				.. playerViolations[userId]
				.. "/"
				.. MAX_VIOLATIONS
				.. ")"
		)

		-- Kick if too many violations
		if playerViolations[userId] >= MAX_VIOLATIONS then
			player:Kick("Too many remote requests. Possible exploit detected.")
		end

		return false -- Rate limited
	end

	playerCooldowns[userId][remoteName] = currentTime
	return true -- Allowed
end

return Network

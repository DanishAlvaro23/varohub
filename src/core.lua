-- src/core.lua
-- Modul inti varohub: state, event bus, util, lifecycle.

local Core = {}

-- ====== SERVICES ======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ====== LOG ======
local DEBUG = true
local function log(...)
	if DEBUG then print("[varohub:core]", ...) end
end

-- ====== STATE ======
local STATE = {
	flags = {},
	events = {},
	connections = {},
	modules = {},
	gui = nil,
	loaded = false,
	startTime = os.time(),
	placeId = game.PlaceId,
	jobId = game.JobId,
}

function STATE:flag(name, default)
	if self.flags[name] == nil then self.flags[name] = default end
	return self.flags[name]
end

function STATE:setFlag(name, value)
	local old = self.flags[name]
	self.flags[name] = value
	self:emit("flag:" .. name, value, old)
end

function STATE:on(name, cb)
	self.events[name] = self.events[name] or {}
	table.insert(self.events[name], cb)
	return function()
		local i = table.find(self.events[name], cb)
		if i then table.remove(self.events[name], i) end
	end
end

function STATE:emit(name, ...)
	for _, cb in ipairs(self.events[name] or {}) do
		task.spawn(function()
			local ok, err = pcall(cb, ...)
			if not ok then warn("[varohub:core] event error " .. name .. ":", err) end
		end)
	end
end

-- ====== UTIL ======
local Util = {}

function Util.char() return player.Character end

function Util.root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function Util.humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Util.tween(obj, props, dur, style, dir)
	return TweenService:Create(
		obj,
		TweenInfo.new(dur or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	):Play()
end

function Util.jsonEncode(t) return HttpService:JSONEncode(t) end

function Util.jsonDecode(s)
	local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
	if ok then return res end
	return nil
end

function Util.urlEncode(s) return HttpService:UrlEncode(s) end

function Util.httpGet(url)
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if not ok then return nil, body end
	return body
end

function Util.httpPost(url, data, contentType)
	local ok, res = pcall(function()
		return HttpService:PostAsync(url, data, contentType or Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then return nil, res end
	return res
end

function Util.deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then out[k] = Util.deepCopy(v) else out[k] = v end
	end
	return out
end

function Util.track(conn, bucket)
	bucket = bucket or "default"
	STATE.connections[bucket] = STATE.connections[bucket] or {}
	table.insert(STATE.connections[bucket], conn)
	return conn
end

function Util.disconnectBucket(bucket)
	for _, c in ipairs(STATE.connections[bucket] or {}) do
		pcall(function() c:Disconnect() end)
	end
	STATE.connections[bucket] = {}
end

function Util.safeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[varohub:core] safeCall:", err) end
	return ok, err
end

function Util.waitFor(parent, name, timeout)
	timeout = timeout or 5
	local t = 0
	while t < timeout do
		local c = parent:FindFirstChild(name)
		if c then return c end
		task.wait(0.1)
		t += 0.1
	end
	return nil
end

function Util.findRemote(name)
	local ok, res = pcall(function()
		return game:GetService("ReplicatedStorage"):FindFirstChild(name, true)
	end)
	if ok and res and res:IsA("RemoteEvent") then return res end
	return nil
end

function Util.fireRemote(name, ...)
	local r = Util.findRemote(name)
	if r then pcall(function() r:FireServer(...) end) return true end
	return false
end

-- ====== MODULE REGISTRY ======
function STATE:register(name, mod)
	self.modules[name] = mod
	log("register:", name)
end

function STATE:get(name)
	return self.modules[name]
end

function STATE:destroyAll()
	for name, mod in pairs(self.modules) do
		if type(mod) == "table" and mod.destroy then
			pcall(mod.destroy)
			log("destroy:", name)
		end
	end
	for bucket, _ in pairs(self.connections) do
		Util.disconnectBucket(bucket)
	end
	self.modules = {}
	self.events = {}
	self.flags = {}
	self.loaded = false
end

-- ====== API ======
Core.STATE = STATE
Core.Util = Util
Core.log = log
Core.Services = {
	Players = Players,
	RunService = RunService,
	UserInputService = UserInputService,
	HttpService = HttpService,
	TweenService = TweenService,
	player = player,
}

function Core.init(ctx)
	if ctx and ctx.state then
		-- merge flags dari loader
		for k, v in pairs(ctx.state.flags or {}) do
			if STATE.flags[k] == nil then STATE.flags[k] = v end
		end
	end
	STATE.loaded = true
	log("core ready")
	return Core
end

function Core.destroy()
	STATE:destroyAll()
end

return Core
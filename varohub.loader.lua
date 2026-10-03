-- varohub.loader.lua
-- Entry point varohub. Jalankan via executor.
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/DanishAlvaro23/varohub/main/varohub.loader.lua"))()

local LOADER = {}

-- ====== KONFIG LOADER ======
LOADER.Config = {
	NAME = "varohub",
	VERSION = "1.0.0",
	BASE_URL = "https://raw.githubusercontent.com/DanishAlvaro23/varohub/main/",
	FILES = {
		core     = "src/core.lua",
		ui       = "src/ui.lua",
		notify   = "src/notify.lua",
		config   = "src/config.lua",
		features = "src/features.lua",
	},
	KEY_REQUIRED = false,
	DEBUG = true,
	CACHE_BUST = true, -- tambah ?t=timestamp biar gak kena cache raw github
}

-- ====== SERVICES ======
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- ====== UTIL ======
local function log(...)
	if LOADER.Config.DEBUG then print("[varohub]", ...) end
end

local function fetch(path)
	local url = LOADER.Config.BASE_URL .. path
	if LOADER.Config.CACHE_BUST then
		url = url .. "?t=" .. tostring(os.time())
	end
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if not ok or not body or #body == 0 then
		error("[varohub] gagal ambil: " .. url)
	end
	return body
end

local function compile(chunk, name)
	local fn, err = loadstring(chunk, "@" .. name)
	if not fn then
		error("[varohub] compile gagal " .. name .. ": " .. tostring(err))
	end
	return fn
end

local function loadModule(name)
	local path = LOADER.Config.FILES[name]
	if not path then error("[varohub] modul tidak dikenal: " .. name) end
	log("fetch:", name)
	local src = fetch(path)
	local fn = compile(src, name)
	local mod = fn()
	return mod
end

-- ====== PARENT GUI ======
local function resolveParent()
	if gethui then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok2, protect = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and protect then
		local ok3 = pcall(function()
			local test = Instance.new("Frame")
			test.Parent = protect
			test:Destroy()
		end)
		if ok3 then return protect end
	end
	return player:WaitForChild("PlayerGui")
end

-- ====== BOOT ======
function LOADER.boot()
	log("boot", LOADER.Config.NAME, LOADER.Config.VERSION)

	-- 1. core
	local Core = loadModule("core")
	Core.init()
	log("core ready")

	-- 2. notify
	local Notify = loadModule("notify")

	-- 3. ui
	local UI = loadModule("ui")
	UI.init(Core)

	-- 4. config
	local Config = loadModule("config")
	Config.init(Core)

	-- 5. create window
	local WIN = UI.create({
		name = LOADER.Config.NAME,
		version = LOADER.Config.VERSION,
		parent = resolveParent(),
	})
	log("window created")

	-- 6. notify init pakai GUI dari window
	Notify.init(Core, WIN.instance)

	-- 7. features
	local Features = loadModule("features")
	Features.init({
		core = Core,
		ui = UI,
		notify = Notify,
		config = Config,
		window = WIN,
	})
	log("features ready")

	-- 8. expose
	getgenv().varohub = {
		core = Core,
		ui = UI,
		notify = Notify,
		config = Config,
		features = Features,
		window = WIN,
		version = LOADER.Config.VERSION,
		unload = LOADER.unload,
	}

	Notify.push("varohub", "loaded v" .. LOADER.Config.VERSION, 3, "success")
	log("ready ✅")
end

-- ====== UNLOAD ======
function LOADER.unload()
	local v = getgenv().varohub
	if not v then return end
	if v.features and v.features.destroy then pcall(v.features.destroy) end
	if v.config and v.config.destroy then pcall(v.config.destroy) end
	if v.notify and v.notify.destroy then pcall(v.notify.destroy) end
	if v.window and v.window.destroy then pcall(v.window.destroy) end
	if v.core and v.core.destroy then pcall(v.core.destroy) end
	getgenv().varohub = nil
	log("unloaded")
end

-- ====== RUN ======
getgenv().varohub_loader = LOADER
task.spawn(function()
	local ok, err = pcall(LOADER.boot)
	if not ok then
		warn("[varohub] boot error:", err)
	end
end)

return LOADER
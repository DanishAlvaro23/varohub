-- src/config.lua
-- Sistem simpan/muat flag varohub ke file JSON (executor) atau attribute (fallback).
-- Tidak pakai require. Core di-inject via Config.init(Core).

local Config = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Core = nil
local FILE_PATH = "varohub_config.json"
local ATTR_NAME = "varohub_config"
local PRESET_DIR = "varohub_presets"

local AUTOSAVE_DEBOUNCE = 1.5
local autosaveToken = 0
local autosaveEnabled = true

-- ====== DETEKSI FITUR EXECUTOR ======
local hasFileIO = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
local hasMakeFolder = (type(makefolder) == "function" and type(isfolder) == "function")

local function log(...)
	if Core and Core.log then Core.log("[config]", ...) end
end

-- ====== UTIL FILE ======
local function fileExists(path)
	if hasFileIO then
		local ok, res = pcall(isfile, path)
		return ok and res
	end
	return false
end

local function writeFile(path, content)
	if hasFileIO then
		local ok, err = pcall(writefile, path, content)
		if not ok then log("writefile error:", err) end
		return ok
	end
	return false
end

local function readFile(path)
	if hasFileIO then
		local ok, res = pcall(readfile, path)
		if ok then return res end
		log("readfile error:", res)
	end
	return nil
end

local function ensureDir(dir)
	if hasMakeFolder and not isfolder(dir) then
		pcall(makefolder, dir)
	end
end

-- ====== SERIALIZE ======
local function snapshot()
	return Core.STATE.flags
end

local function serialize(flags)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(flags)
	end)
	if ok then return json end
	return "{}"
end

local function deserialize(json)
	local ok, tbl = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if ok and type(tbl) == "table" then return tbl end
	return nil
end

-- ====== SAVE / LOAD ======
function Config.save()
	local flags = snapshot()
	local json = serialize(flags)

	-- simpan ke file kalau ada
	if hasFileIO then
		writeFile(FILE_PATH, json)
	end

	-- simpan ke attribute player (fallback & mirror)
	pcall(function()
		Players.LocalPlayer:SetAttribute(ATTR_NAME, json)
	end)

	log("saved", tostring(#json) .. " bytes")
	return true
end

function Config.load()
	local json = nil

	if fileExists(FILE_PATH) then
		json = readFile(FILE_PATH)
	end

	if not json then
		local ok, attr = pcall(function()
			return Players.LocalPlayer:GetAttribute(ATTR_NAME)
		end)
		if ok and type(attr) == "string" and #attr > 0 then
			json = attr
		end
	end

	if not json or #json == 0 then
		log("no config ditemukan, pakai default")
		return false
	end

	local flags = deserialize(json)
	if not flags then
		log("config korup, skip")
		return false
	end

	local n = 0
	for k, v in pairs(flags) do
		Core.STATE.flags[k] = v
		n += 1
	end
	log("loaded", n, "flag")
	return true
end

function Config.reset()
	if fileExists(FILE_PATH) then
		if type(delfile) == "function" then pcall(delfile, FILE_PATH) end
	end
	pcall(function()
		Players.LocalPlayer:SetAttribute(ATTR_NAME, nil)
	end)
	Core.STATE.flags = {}
	log("reset")
	return true
end

-- ====== AUTOSAVE ======
function Config.enableAutosave(on)
	autosaveEnabled = on and true or false
end

local function scheduleAutosave()
	if not autosaveEnabled then return end
	autosaveToken += 1
	local myToken = autosaveToken
	task.delay(AUTOSAVE_DEBOUNCE, function()
		if myToken == autosaveToken then
			Config.save()
		end
	end)
end

-- ====== PRESETS ======
function Config.listPresets()
	ensureDir(PRESET_DIR)
	if not hasFileIO or type(listfiles) ~= "function" then return {} end
	local ok, files = pcall(listfiles, PRESET_DIR)
	if not ok then return {} end
	local out = {}
	for _, f in ipairs(files) do
		local name = f:match("([^/\\]+)%.json$")
		if name then table.insert(out, name) end
	end
	return out
end

function Config.savePreset(name)
	if not name or name == "" then return false end
	ensureDir(PRESET_DIR)
	local path = PRESET_DIR .. "/" .. name .. ".json"
	writeFile(path, serialize(snapshot()))
	log("preset saved:", name)
	return true
end

function Config.loadPreset(name)
	if not name or name == "" then return false end
	local path = PRESET_DIR .. "/" .. name .. ".json"
	if not fileExists(path) then return false end
	local json = readFile(path)
	local flags = json and deserialize(json)
	if not flags then return false end
	for k, v in pairs(flags) do Core.STATE.flags[k] = v end
	log("preset loaded:", name)
	return true
end

function Config.deletePreset(name)
	if not name or name == "" then return false end
	local path = PRESET_DIR .. "/" .. name .. ".json"
	if fileExists(path) and type(delfile) == "function" then
		pcall(delfile, path)
		return true
	end
	return false
end

-- ====== INIT ======
function Config.init(core)
	Core = core
	assert(Core, "[varohub:config] Core nil")

	Core.STATE:on("flag:%", function() end) -- no-op, placeholder

	-- hook semua setFlag via wrap
	local STATE = Core.STATE
	local originalSetFlag = STATE.setFlag
	STATE.setFlag = function(self, name, value)
		originalSetFlag(self, name, value)
		scheduleAutosave()
	end

	-- auto-load pas init
	Config.load()

	log("config ready (fileIO=" .. tostring(hasFileIO) .. ")")
	return Config
end

function Config.destroy()
	Config.save()
	log("config destroyed, final save")
end

return Config
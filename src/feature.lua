-- src/features.lua
-- varohub full feature pack: ride, farm, hatch, pick, buy, sell, upgrade, webhook, config.

local Features = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local Core, UI, Notify, Config, WIN

-- =========================================================
-- KONFIG
-- =========================================================
local CFG = {
	RIDE_KEY = Enum.KeyCode.E,
	SEAT_OFFSET = CFrame.new(0, 2.5, 0),
	MAX_DISTANCE = 14,
	FARM_INTERVAL = 0.4,
	HATCH_INTERVAL = 1.2,
	WEBHOOK_INTERVAL = 15,
	TELEPORT_OFFSET = 6,
	TP_SETTLE = 0.1,
	WEBHOOK_URL = "",
	WEBHOOK_NAME = "varohub",
	RARITY_PRIORITY = {
		common = 1, uncommon = 2, rare = 3,
		epic = 4, legendary = 5, mythic = 6,
		secret = 7, godly = 8,
	},
	DEFAULT_RARITY = 0,
}

-- =========================================================
-- STATE
-- =========================================================
local S = {
	riding = false, pet = nil, weld = nil, petHum = nil,
	hatchCount = 0, pickCount = 0, buyGearCount = 0, buyFoodCount = 0,
	sellCount = 0, upgradeCount = 0,
	sessionStart = os.time(),
	rarityFilter = "any",
}

-- =========================================================
-- UTIL
-- =========================================================
local function flag(n, d) return Core.STATE:flag(n, d) end
local function setFlag(n, v) Core.STATE:setFlag(n, v) end
local function root() return Core.Util.root() end
local function humanoid() return Core.Util.humanoid() end
local function notify(t, b, k) if Notify then Notify.push(t, b, 3, k or "default") end end

local function parseList(s)
	local out = {}
	if not s or s == "" then return out end
	for tok in string.gmatch(s, "[^,]+") do
		local t = tok:match("^%s*(.-)%s*$")
		if t ~= "" then table.insert(out, t) end
	end
	return out
end

local function nameMatches(obj, list)
	if not list or #list == 0 then return true end
	local n = string.lower(obj.Name)
	for _, key in ipairs(list) do
		if n:find(string.lower(key), 1, true) then return true end
	end
	return false
end

local function rarityMatches(obj, allowed)
	if not allowed or #allowed == 0 then return true end
	local r = string.lower(readRarity(obj))
	for _, a in ipairs(allowed) do
		if r == string.lower(a) then return true end
	end
	return false
end

local function tpTo(pos)
	local hrp = root()
	if not hrp then return false end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, CFG.TELEPORT_OFFSET, 0))
	pcall(function() hrp:SetNetworkOwner(player) end)
	task.wait(CFG.TP_SETTLE)
	return true
end

-- =========================================================
-- WEBHOOK
-- =========================================================
local function webhook(content, fields)
	local url = flag("webhookUrl", CFG.WEBHOOK_URL)
	if not url or url == "" then return end
	local payload = {
		username = CFG.WEBHOOK_NAME,
		content = content or "",
		embeds = {{
			title = "varohub log",
			color = 0x7A5AFF,
			fields = fields or {},
			footer = { text = "varohub • " .. player.Name },
			timestamp = DateTime.now():ToIsoDate(),
		}},
	}
	task.spawn(function()
		Core.Util.httpPost(url, HttpService:JSONEncode(payload))
	end)
end

-- =========================================================
-- RARITY
-- =========================================================
function readRarity(obj)
	local a = obj:GetAttribute("Rarity") or obj:GetAttribute("RarityName") or obj:GetAttribute("Tier")
	if type(a) == "string" then return a end
	if type(a) == "number" then
		for k, v in pairs(CFG.RARITY_PRIORITY) do if v == a then return k end end
		return tostring(a)
	end
	for _, d in ipairs(obj:GetDescendants()) do
		if d:GetAttribute then
			local da = d:GetAttribute("Rarity") or d:GetAttribute("RarityName")
			if type(da) == "string" then return da end
		end
		if d:IsA("StringValue") and string.lower(d.Name):find("rarity") then
			return d.Value
		end
	end
	local n = string.lower(obj.Name)
	for k, _ in pairs(CFG.RARITY_PRIORITY) do if n:find(k) then return k end end
	return "unknown"
end

local function rarityScore(obj)
	local r = string.lower(readRarity(obj))
	return CFG.RARITY_PRIORITY[r] or CFG.DEFAULT_RARITY
end

-- =========================================================
-- PET: RIDE
-- =========================================================
local function getPets()
	local out = {}
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Owner") == player.UserId then
			local r = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
			if r then table.insert(out, {model = obj, root = r}) end
		end
	end
	return out
end

local function getNearestPet()
	local hrp = root() if not hrp then return nil end
	local best, bestD
	for _, p in ipairs(getPets()) do
		local d = (p.root.Position - hrp.Position).Magnitude
		if not bestD or d < bestD then best, bestD = p, d end
	end
	if best and bestD and bestD <= CFG.MAX_DISTANCE then return best end
	return nil
end

local function mount(petEntry)
	if S.riding or not petEntry then return end
	local hrp, hum = root(), humanoid()
	if not (hrp and hum) then return end
	S.petHum = petEntry.model:FindFirstChildOfClass("Humanoid")
	if S.petHum then S.petHum.PlatformStand = true end
	hum.PlatformStand = true
	hrp.CFrame = petEntry.root.CFrame * CFG.SEAT_OFFSET
	S.weld = Instance.new("WeldConstraint")
	S.weld.Part0 = petEntry.root
	S.weld.Part1 = hrp
	S.weld.Parent = hrp
	S.riding = true S.pet = petEntry.model
	notify("Ride", "naik: " .. petEntry.model.Name, "success")
end

local function dismount()
	if not S.riding then return end
	local hrp, hum = root(), humanoid()
	if hrp then hrp.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 4 + Vector3.new(0, 2, 0)) end
	if hum then hum.PlatformStand = false end
	if S.petHum then S.petHum.PlatformStand = false end
	if S.weld then S.weld:Destroy() S.weld = nil end
	S.riding = false S.pet = nil S.petHum = nil
	notify("Ride", "turun", "info")
end

local function toggleRide()
	if S.riding then dismount() else mount(getNearestPet()) end
end

-- =========================================================
-- EGG: SCAN + HATCH
-- =========================================================
local function scanEggs()
	local eggs = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local n = string.lower(obj.Name)
			if n:find("egg") or obj:GetAttribute("EggId") or obj:GetAttribute("Hatchable") then
				local r = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
				if r then
					table.insert(eggs, {obj=obj, root=r, rarity=readRarity(obj), score=rarityScore(obj)})
				end
			end
		end
	end
	return eggs
end

local function pickEgg()
	local hrp = root() if not hrp then return nil end
	local eggs = scanEggs()
	if #eggs == 0 then return nil end
	local filter = S.rarityFilter
	if filter ~= "any" then
		local f = {}
		for _, e in ipairs(eggs) do if string.lower(e.rarity) == filter then table.insert(f, e) end end
		if #f > 0 then eggs = f end
	end
	local mode = flag("farmMode", "highest")
	local best, bestKey
	for _, e in ipairs(eggs) do
		local key
		if mode == "nearest" then key = -(e.root.Position - hrp.Position).Magnitude
		elseif mode == "lowest" then key = -e.score
		else key = e.score end
		if not bestKey or key > bestKey then best, bestKey = e, key end
	end
	return best
end

local function tryHatch(eggEntry)
	if not eggEntry then return false end
	if not tpTo(eggEntry.root.Position) then return false end
	for _, d in ipairs(eggEntry.obj:GetDescendants()) do
		if d:IsA("ProximityPrompt") then fireproximityprompt(d) S.hatchCount += 1 return true end
	end
	for _, d in ipairs(eggEntry.obj:GetDescendants()) do
		if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) S.hatchCount += 1 return true end
	end
	for _, name in ipairs({"HatchEgg","Hatch","BuyEgg","EggHatch"}) do
		local r = Core.Util.findRemote(name)
		if r then pcall(function() r:FireServer(eggEntry.obj) end) S.hatchCount += 1 return true end
	end
	return false
end

-- =========================================================
-- AUTO PICK
-- =========================================================
local function scanPickables()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Tool") then
			local n = string.lower(obj.Name)
			if obj:GetAttribute("Pickable") or obj:GetAttribute("Collectable")
				or n:find("drop") or n:find("pickup") or n:find("coin")
				or n:find("gem") or n:find("item") then
				local r = obj:IsA("BasePart") and obj
					or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
				if r then table.insert(out, {obj=obj, root=r, rarity=readRarity(obj)}) end
			end
		end
	end
	return out
end

local function tryPick(obj)
	local p = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if p then fireproximityprompt(p) return true end
	local c = obj:FindFirstChildWhichIsA("ClickDetector", true)
	if c then pcall(function() fireclickdetector(c) end) return true end
	for _, name in ipairs({"Pickup","Collect","Pick","PickupItem"}) do
		local rem = Core.Util.findRemote(name)
		if rem then pcall(function() rem:FireServer(obj) end) return true end
	end
	return false
end

-- =========================================================
-- AUTO BUY GEAR
-- =========================================================
local function scanGear()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Tool") then
			local n = string.lower(obj.Name)
			if obj:GetAttribute("GearId") or obj:GetAttribute("Buyable")
				or n:find("gear") or n:find("weapon") or n:find("sword") or n:find("armor") then
				local r = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
				if r then table.insert(out, {obj=obj, root=r, name=obj.Name, rarity=readRarity(obj)}) end
			end
		end
	end
	return out
end

local function tryBuyGear(obj)
	local p = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if p then fireproximityprompt(p) return true end
	local c = obj:FindFirstChildWhichIsA("ClickDetector", true)
	if c then pcall(function() fireclickdetector(c) end) return true end
	for _, name in ipairs({"BuyGear","Buy","Purchase","BuyItem","BuyWeapon"}) do
		local rem = Core.Util.findRemote(name)
		if rem then pcall(function() rem:FireServer(obj) end) return true end
	end
	return false
end

-- =========================================================
-- AUTO BUY FOOD
-- =========================================================
local function scanFood()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Tool") then
			local n = string.lower(obj.Name)
			if obj:GetAttribute("FoodId") or obj:GetAttribute("Edible")
				or n:find("food") or n:find("fruit") or n:find("meat")
				or n:find("potion") or n:find("consume") then
				local r = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
				if r then table.insert(out, {obj=obj, root=r, name=obj.Name, rarity=readRarity(obj)}) end
			end
		end
	end
	return out
end

local function tryBuyFood(obj)
	local p = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if p then fireproximityprompt(p) return true end
	local c = obj:FindFirstChildWhichIsA("ClickDetector", true)
	if c then pcall(function() fireclickdetector(c) end) return true end
	for _, name in ipairs({"BuyFood","BuyConsumable","Buy","Purchase","Consume"}) do
		local rem = Core.Util.findRemote(name)
		if rem then pcall(function() rem:FireServer(obj) end) return true end
	end
	return false
end

-- =========================================================
-- AUTO SELL
-- =========================================================
local function scanSellAreas()
	local out = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local n = string.lower(obj.Name)
			if obj:GetAttribute("SellArea") or n:find("sell") then
				local r = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
				if r then table.insert(out, {obj=obj, root=r}) end
			end
		end
	end
	return out
end

local function trySell()
	for _, name in ipairs({"SellAll","Sell","SellPet","SellPets","SellItem"}) do
		local rem = Core.Util.findRemote(name)
		if rem then pcall(function() rem:FireServer() end) S.sellCount += 1 return true end
	end
	for _, area in ipairs(scanSellAreas()) do
		local p = area.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p then fireproximityprompt(p) S.sellCount += 1 return true end
	end
	return false
end

-- =========================================================
-- AUTO UPGRADE
-- =========================================================
local function tryUpgrade()
	for _, name in ipairs({"Upgrade","UpgradePet","LevelUp","Evolve","Fuse"}) do
		local rem = Core.Util.findRemote(name)
		if rem then pcall(function() rem:FireServer() end) S.upgradeCount += 1 return true end
	end
	return false
end

-- =========================================================
-- AUTO EQUIP
-- =========================================================
local function tryEquip()
	for _, name in ipairs({"EquipBest","Equip","AutoEquip","EquipPets"}) do
		if Core.Util.fireRemote(name) then return true end
	end
	return false
end

-- =========================================================
-- LOOPS
-- =========================================================
local function startAutoFarm()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("farmInterval", CFG.FARM_INTERVAL))
			if flag("autoFarm", false) and not S.riding then
				local egg = pickEgg()
				if egg then tryHatch(egg) end
			end
		end
	end)
end

local function startAutoHatch()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(CFG.HATCH_INTERVAL)
			if flag("autoHatch", false) then
				local egg = pickEgg()
				if egg then tryHatch(egg) end
			end
		end
	end)
end

local function startAutoPick()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("pickInterval", 0.3))
			if flag("autoPick", false) then
				local names = parseList(flag("pickNames", ""))
				local rar = parseList(flag("pickRarities", ""))
				local hrp = root()
				if hrp then
					for _, item in ipairs(scanPickables()) do
						if nameMatches(item.obj, names) and rarityMatches(item.obj, rar) then
							local d = (item.root.Position - hrp.Position).Magnitude
							if d < flag("pickRange", 60) then
								tpTo(item.root.Position)
								if tryPick(item.obj) then S.pickCount += 1 end
								break
							end
						end
					end
				end
			end
		end
	end)
end

local function startAutoBuyGear()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("buyGearInterval", 1))
			if flag("autoBuyGear", false) then
				local names = parseList(flag("buyGearNames", ""))
				local rar = parseList(flag("buyGearRarities", ""))
				for _, g in ipairs(scanGear()) do
					if nameMatches(g.obj, names) and rarityMatches(g.obj, rar) then
						if tryBuyGear(g.obj) then
							S.buyGearCount += 1
							webhook("gear dibeli: " .. g.name)
						end
					end
				end
			end
		end
	end)
end

local function startAutoBuyFood()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("buyFoodInterval", 1))
			if flag("autoBuyFood", false) then
				local names = parseList(flag("buyFoodNames", ""))
				local rar = parseList(flag("buyFoodRarities", ""))
				local maxPrice = flag("buyFoodMaxPrice", 0)
				for _, f in ipairs(scanFood()) do
					if nameMatches(f.obj, names) and rarityMatches(f.obj, rar) then
						local price = tonumber(f.obj:GetAttribute("Price")) or 0
						if maxPrice == 0 or price <= maxPrice then
							if tryBuyFood(f.obj) then
								S.buyFoodCount += 1
								webhook("food dibeli: " .. f.name)
							end
						end
					end
				end
			end
		end
	end)
end

local function startAutoSell()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("sellInterval", 5))
			if flag("autoSell", false) then trySell() end
		end
	end)
end

local function startAutoUpgrade()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("upgradeInterval", 5))
			if flag("autoUpgrade", false) then tryUpgrade() end
		end
	end)
end

local function startAutoEquip()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(3)
			if flag("autoEquip", false) then tryEquip() end
		end
	end)
end

local function startWebhookLoop()
	task.spawn(function()
		while Core.STATE.loaded do
			task.wait(flag("webhookInterval", CFG.WEBHOOK_INTERVAL))
			if flag("webhookEnabled", false) then
				webhook("", {
					{ name = "uptime (s)", value = tostring(os.time() - S.sessionStart), inline = true },
					{ name = "hatch", value = tostring(S.hatchCount), inline = true },
					{ name = "pick", value = tostring(S.pickCount), inline = true },
					{ name = "buy gear", value = tostring(S.buyGearCount), inline = true },
					{ name = "buy food", value = tostring(S.buyFoodCount), inline = true },
					{ name = "sell", value = tostring(S.sellCount), inline = true },
				})
			end
		end
	end)
end

-- =========================================================
-- UI BUILD
-- =========================================================
local function buildUI()
	local main  = WIN.tab("Main")
	local farm  = WIN.tab("Farm")
	local pick  = WIN.tab("Pick")
	local buy   = WIN.tab("Buy")
	local misc  = WIN.tab("Misc")
	local cfgTab= WIN.tab("Config")

	-- MAIN
	UI.button(main, "RIDE / DISMOUNT  [E]", toggleRide)
	UI.toggle(main, "Auto Farm Egg", "autoFarm", false)
	UI.toggle(main, "Auto Hatch Egg", "autoHatch", false)
	UI.toggle(main, "Auto Equip Best", "autoEquip", true)
	UI.toggle(main, "Auto Upgrade", "autoUpgrade", false)
	UI.toggle(main, "Auto Sell", "autoSell", false)
	UI.divider(main)
	UI.label(main, "session stats")
	UI.label(main, "hatch: 0 | pick: 0 | sell: 0")

	-- FARM
	UI.label(farm, "mode prioritas egg")
	UI.button(farm, "MODE: HIGHEST", function(b)
		local modes = {"highest","nearest","lowest"}
		local cur = flag("farmMode", "highest")
		local i = table.find(modes, cur) or 1
		local nxt = modes[(i % #modes) + 1]
		setFlag("farmMode", nxt)
		b.Text = "MODE: " .. string.upper(nxt)
	end)
	UI.button(farm, "FILTER RARITY: ANY", function(b)
		local list = {"any"}
		for k, _ in pairs(CFG.RARITY_PRIORITY) do table.insert(list, k) end
		table.sort(list)
		local i = table.find(list, S.rarityFilter) or 1
		S.rarityFilter = list[(i % #list) + 1]
		b.Text = "FILTER RARITY: " .. string.upper(S.rarityFilter)
	end)
	UI.slider(farm, "Farm Interval", "farmInterval", 1, 20, CFG.FARM_INTERVAL)
	UI.button(farm, "TP KE EGG TERDEKAT", function()
		local egg = pickEgg()
		if egg then
			tpTo(egg.root.Position)
			notify("TP", egg.obj.Name .. " [" .. egg.rarity .. "]", "info")
		else
			notify("TP", "no egg", "warn")
		end
	end)

	-- PICK
	UI.toggle(pick, "Auto Pick", "autoPick", false)
	UI.slider(pick, "Pick Range", "pickRange", 10, 200, 60)
	UI.slider(pick, "Pick Interval", "pickInterval", 1, 10, 0.3)
	UI.divider(pick)
	UI.label(pick, "filter nama (pisah koma):")
	UI.button(pick, "SET NAMA PICK", function()
		notify("Pick", "pickNames = " .. flag("pickNames", ""), "info")
	end)
	UI.label(pick, "filter rarity (common,rare):")
	UI.button(pick, "SET RARITY PICK", function()
		notify("Pick", "pickRarities = " .. flag("pickRarities", ""), "info")
	end)

	-- BUY
	UI.toggle(buy, "Auto Buy Gear", "autoBuyGear", false)
	UI.slider(buy, "Gear Int
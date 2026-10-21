if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not LPH_OBFUSCATED then
    local function Passthrough(fn) return fn end
    LPH_JIT, LPH_JIT_MAX, LPH_NO_VIRTUALIZE = Passthrough, Passthrough, Passthrough
end

local environment = getgenv and getgenv() or _G
if type(environment.AnimeDiceUnload) == "function" then
    pcall(environment.AnimeDiceUnload)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local osClock = os.clock

if game.GameId ~= 10708913337 then
    LocalPlayer:Kick("Lazy Jiro Hub: this script is for Anime Dice only")
    return
end

local Banner = {
    Print = print,
    Started = os.clock(),
    Last = os.clock(),
    Done = 0,
    Total = 4,
}

do
    local ok, renv = pcall(getrenv)
    if ok and type(renv) == "table" and type(renv.print) == "function" then Banner.Print = renv.print end
end

function Banner.Show()
    local ok, executor = pcall(identifyexecutor)
    if not ok or type(executor) ~= "string" then executor = "Unknown" end
    local rule = string.rep("=", 54)
    Banner.Print(table.concat({
        "",
        rule,
        "   LAZY JIRO HUB  //  ANIME DICE",
        "   executor: " .. executor .. "   //   player: " .. LocalPlayer.Name,
        rule,
    }, "\n"))
end

---@param label string  what just finished loading
function Banner.Step(label)
    local now = os.clock()
    Banner.Done = math.min(Banner.Done + 1, Banner.Total)
    local filled = math.floor(Banner.Done / Banner.Total * 20 + 0.5)
    Banner.Print(string.format("[Lazy Jiro Hub] [%s] %3d%%  %-24s +%dms",
        string.rep("#", filled) .. string.rep(".", 20 - filled),
        math.floor(Banner.Done / Banner.Total * 100), label, math.floor((now - Banner.Last) * 1000)))
    Banner.Last = now
end

function Banner.Ready()
    local rule = string.rep("=", 54)
    Banner.Print(table.concat({
        rule,
        string.format("   >> READY in %dms", math.floor((os.clock() - Banner.Started) * 1000)),
        rule,
    }, "\n"))
end

pcall(Banner.Show)
pcall(Banner.Step, "Core")

local Hub = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, type(value) == "function" and LPH_JIT(value) or value)
    end,
})

Hub.Config = {
    UiSource = environment.LazyJiroUiSource or "https://raw.githubusercontent.com/LazyJiroHub/LazyHub/refs/heads/main/LazyJiroUI.lua",
    Discord = "https://discord.gg/D8SM7VfTKZ",
    ReloadSource = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/LazyJiroHub/LazyHub/refs/heads/main/Loader.lua"))()',
    RejoinDelay = 5,
    RejoinRetry = 30,
    WebhookColor = 0xE8A04C,
    GroupId = 33017480,
    SaveFolder = "LazyJiroHub",
    ConfigFile = "AnimeDice_config.json",
    AutoloadFile = "AnimeDice_autoload.txt",
    LoadTimeout = 10,
    AlertTries = 20,
    AlertGap = 0.5,
    JobFailLimit = 5,
    JobFailWindow = 10,
    StatusInterval = 1,
    RollLead = 0.1,
    GradeDelay = 0.3,
    TraitDelay = 0.3,
    FuseDelay = 0.55,
    BuyDelay = 0.3,
    LevelDelay = 0.2,
    RedeemDelay = 0.6,
    ClaimDelay = 0.25,
    TowerTick = 0.25,
    TowerRetry = 0.5,
    TowerStartCooldown = 3.2,
    ItemDelay = 0.6,
    StatDelay = 0.12,
    RewardsInterval = 5,
    SnapshotTtl = 0.4,
    StorageHeadroom = 6,
    StorageRefill = 0.7,
    TowerDemoteFloor = 5,
    RollStats = { Luck = true, ["Roll Duration"] = true, Rolls = true },
    UtilitySeconds = { Default = 120, Walkspeed = 10, ["Sell Multiplier"] = 60, ["Unit Storage"] = 180, Luck = 600, ["Roll Duration"] = 600 },
    UtilityFallbackShare = 0.05,
    SwapMargin = 1.15,
    FuseGain = 1.25,
    FuseMoneyShare = 0.05,
    SwapsPerPass = 4,
    PlaceDelay = 0.55,
    TowerActionTime = {
        floorStarted = 0.76,
        damageEnemy = 0.62,
        damagePlayer = 0.62,
        memberDefeated = 0.32,
        floorCompleted = 0.24,
    },
}

Hub.State = {
    Alive = true,
    Unloaded = false,
    Connections = {},
    Halted = {},
    Notices = {},
}

Hub.Options = {
    AntiAfk = false,
    DisableCutscene = false,

    WalkSpeed = false,
    WalkSpeedValue = 32,
    InfiniteJump = false,
    NoClip = false,
    Fly = false,
    FlySpeed = 60,

    AutoRoll = false,
    RollInterval = 0.02,

    AutoCollect = false,
    CollectInterval = 1,
    EquipBestUnitsAuto = false,
    EquipInterval = 5,
    PlacementMode = "Potential",
    AutoLevelUp = false,
    LevelMinRarity = "Common",
    LevelTarget = 10,

    AutoBuyDice = false,
    AutoEquipBestDice = false,
    AutoBuyUpgrades = false,
    UpgradeFilter = {},

    AutoSell = false,
    SellRarities = {},
    SellKeepMutations = {},
    KeepPerRarity = 0,
    SellInterval = 2,
    AutoClearStorage = false,
    ClearKeepRarity = "Mythical",
    LevelPayback = 180,
    UpgradePayback = 1800,

    AutoRebirth = false,
    AutoRebirthStats = false,
    RebirthStat = "Money",

    AutoGrade = false,
    GradeTarget = "S",
    GradeOverwrite = false,
    AutoTrait = false,
    TraitTarget = "Samurai",
    TraitOverwrite = false,
    AutoFuse = false,
    FuseRarities = {},

    AutoTower = false,
    TowerName = "Dragon Tower",
    TowerStopFloor = 100,
    TowerReequip = false,
    TowerSmart = false,

    AutoGear = false,
    AutoPotion = false,
    PotionFilter = {},
    AutoSpin = false,
    AutoGamepass = false,
    AutoTicketShop = false,
    TicketShopItems = {},

    AutoDaily = false,
    AutoGroup = false,
    AutoOffline = false,
    AutoQuest = false,

    RareNotify = false,
    NotifyRarities = {},
    NotifyMutations = {},
    WebhookUrl = "",
    AutoLock = false,
    LockRarity = "Secret I",
    LockMutations = {},
    AutoRejoin = false,

    Kaitun = false,
}

Hub.Util = {}
local Util = Hub.Util

---@return function?  first argument that is callable
local function Resolve(...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "function" then
            return candidate
        end
    end
    return nil
end

Util.Request = Resolve(request, http_request, syn and syn.request, http and http.request)
Util.SetClipboard = Resolve(setclipboard, toclipboard)
Util.QueueTeleport = Resolve(queue_on_teleport, queueonteleport, syn and syn.queue_on_teleport)

---@return string?, string?  body, or nil and why every transport failed
function Util.HttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then
        return body
    end
    if not Util.Request then return nil, "no http function" end

    local sent, response = pcall(Util.Request, { Url = url, Method = "GET" })
    if not sent or type(response) ~= "table" then return nil, tostring(response) end
    if response.StatusCode ~= 200 or type(response.Body) ~= "string" then
        return nil, "HTTP " .. tostring(response.StatusCode)
    end
    return response.Body
end

---@param detail any?  extra context for the console only
function Util.Alert(text, detail)
    warn("[AnimeDice] " .. text, detail or "")
    task.spawn(function()
        local starterGui = game:GetService("StarterGui")
        for _ = 1, Hub.Config.AlertTries do
            if pcall(starterGui.SetCore, starterGui, "SendNotification", { Title = "Lazy Jiro Hub", Text = text, Duration = 10 }) then return end
            task.wait(Hub.Config.AlertGap)
        end
    end)
end

function Util.Copy(text)
    if not Util.SetClipboard then return false end
    return (pcall(Util.SetClipboard, text))
end

---@return boolean  fn finished without error
function Util.Try(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[AnimeDice] " .. label .. ":", err) end
    return ok
end

---@return table?, string?  UI library, or nil and a message for the player
function Util.LoadLibrary(url)
    local source, why = Util.HttpGet(url)
    if not source or not source:sub(-64):find("return%s+Lib%s*$") then
        warn("[AnimeDice] ui download:", why or "truncated or not the library")
        return nil, "Could not download the menu. Check your connection and run it again."
    end
    local chunk, compileErr = loadstring(source)
    if not chunk then
        return nil, "The menu failed to load on this executor: " .. tostring(compileErr)
    end
    local ok, lib = pcall(chunk)
    if not ok or type(lib) ~= "table" then
        return nil, "The menu failed to load on this executor: " .. tostring(lib)
    end
    return lib
end

function Util.FormatNumber(value)
    value = tonumber(value) or 0
    if value >= 1e6 then
        local suffixes = { "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
        local tier = math.clamp(math.floor(math.log(value, 1000)) - 1, 1, #suffixes)
        return string.format("%.2f%s", value / (1000 ^ (tier + 1)), suffixes[tier])
    end
    local text = tostring(math.floor(value))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

---@return string[]  sorted keys, stable dropdown order
function Util.SortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

function Util.SetFromList(list)
    local set = {}
    for key, value in pairs(list or {}) do
        if type(key) == "number" then
            set[value] = true
        elseif value then
            set[key] = true
        end
    end
    return set
end

function Hub:Connect(signal, handler)
    local connection = signal:Connect(handler)
    table.insert(self.State.Connections, connection)
    return connection
end

Hub.GameLib = {}
local GameLib = Hub.GameLib

---@return Instance?  descendant at a dotted path, nil when any part is missing
function GameLib.Find(root, path)
    local node = root
    for part in path:gmatch("[^.]+") do
        if not node then return nil end
        node = node:FindFirstChild(part)
    end
    return node
end

---@return boolean, any  ok and module, required from a fresh identity-2 thread
function GameLib.RequireAsGame(module)
    if GameLib.CanSwitch == false then return false, nil end

    local done, ok, loaded = false, false, nil
    task.spawn(function()
        local switched = pcall(setthreadidentity, 2)
        local read, identity = pcall(getthreadidentity)
        if switched and read and identity == 2 then
            ok, loaded = pcall(require, module)
        else
            GameLib.CanSwitch = false
        end
        done = true
    end)
    local deadline = osClock() + Hub.Config.LoadTimeout
    while not done and osClock() < deadline do task.wait() end
    return ok, loaded
end

---@return any?  module, nil when it is missing or no identity can require it
function GameLib.Require(module)
    if not (module and module:IsA("ModuleScript")) then return nil end
    local ok, loaded = pcall(require, module)
    if ok then return loaded end
    local retried, again = GameLib.RequireAsGame(module)
    if retried then return again end
    warn("[AnimeDice] require " .. module:GetFullName() .. ":", loaded)
    return nil
end

do
    local framework = ReplicatedStorage:WaitForChild("Framework", Hub.Config.LoadTimeout)
    local features = framework and framework:WaitForChild("Features", Hub.Config.LoadTimeout)
    local function Load(path) return GameLib.Require(GameLib.Find(features, path)) end

    GameLib.Dice = Load("Rolling.Dice")
    GameLib.Rebirths = Load("Rebirth.Rebirths")
    GameLib.Upgrades = Load("Upgrades.Upgrades")
    GameLib.Tree = Load("Upgrades.TreeStructure")
    GameLib.Grades = Load("Grades.Grades")
    GameLib.Traits = Load("Traits.Traits")
    GameLib.Towers = Load("Towers.Towers")
    GameLib.Rarities = GameLib.Require(GameLib.Find(framework, "Other.Rarities"))
    GameLib.Entry = Load("Inventory.EntryRegistry")
    GameLib.Mutations = Load("Inventory.Kinds.Unit.Mutations")
    GameLib.UnitUtil = Load("Inventory.Kinds.Unit.UnitUtil")
    GameLib.Codes = Load("Codes.CodesConfig")
    GameLib.Quests = Load("Quests.QuestConfig")
    GameLib.RollController = Load("Rolling.RollController")
    GameLib.Buffs = Load("Buffs.BuffController")
    GameLib.BuffsConfig = Load("Buffs.BuffsConfig")
    GameLib.FusingConfig = Load("Fusing.FusingConfig")
    GameLib.RebirthStats = Load("Rebirth.RebirthStatsConfig")

    local rewards = GameLib.Find(features, "Rewards")
    GameLib.Daily = GameLib.Require(rewards and rewards:FindFirstChild("DailyRewardConfig", true))
    GameLib.Group = GameLib.Require(rewards and rewards:FindFirstChild("GroupRewardConfig", true))
    GameLib.DataClient = GameLib.Require(GameLib.Find(ReplicatedStorage, "Packages.Data.Client"))
end

GameLib.EntryCache = {}

function GameLib.EntryOf(name)
    local registry = GameLib.Entry
    if not registry or not name then return nil end
    local cached = GameLib.EntryCache[name]
    if cached ~= nil then return cached or nil end
    local ok, config = pcall(registry.getEntryConfig, name)
    GameLib.EntryCache[name] = ok and config or false
    return ok and config or nil
end

function GameLib.GradeOrder(gradeName)
    local grade = gradeName and GameLib.Grades and GameLib.Grades[gradeName]
    return type(grade) == "table" and tonumber(grade.order) or 0
end

---@return number  strongest multiplier, order breaks ties
function GameLib.TraitPower(traitName)
    local trait = traitName and GameLib.Traits and GameLib.Traits[traitName]
    if type(trait) ~= "table" then return 0 end
    local best = math.max(tonumber(trait.incomeMultiplier) or 0, tonumber(trait.damageMultiplier) or 0,
        tonumber(trait.healthMultiplier) or 0)
    return best + (tonumber(trait.order) or 0) / 1000
end

function GameLib.RarityOrder(rarityName)
    local rarities = GameLib.Rarities
    if not rarities or not rarityName then return 0 end
    local ok, entry = pcall(rarities.Get, rarityName)
    return ok and type(entry) == "table" and tonumber(entry.sortOrder) or 0
end

---@return string[]  names of every entry of a kind, sorted
function GameLib.NamesOfKind(kind)
    local registry = GameLib.Entry
    local names = {}
    if not registry then return names end
    local ok, entries = pcall(registry.entriesOfKind, kind)
    if ok and type(entries) == "table" then
        for name in pairs(entries) do names[#names + 1] = tostring(name) end
    end
    table.sort(names)
    return names
end

function GameLib.RebirthStatNames()
    local names = {}
    local config = GameLib.RebirthStats
    if not (config and type(config.Stats) == "table") then return names end
    for _, stat in ipairs(config.Stats) do names[#names + 1] = tostring(stat.name) end
    return names
end

function GameLib.GradeNames()
    local names = Util.SortedKeys(GameLib.Grades or {})
    table.sort(names, function(a, b) return GameLib.GradeOrder(a) < GameLib.GradeOrder(b) end)
    return names
end

function GameLib.TraitNames()
    local names = {}
    for name, trait in pairs(GameLib.Traits or {}) do
        if type(trait) == "table" and GameLib.TraitPower(name) > 0 then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return GameLib.TraitPower(a) < GameLib.TraitPower(b) end)
    return names
end

function GameLib.MutationNames()
    local names = {}
    for name, mutation in pairs(GameLib.Mutations or {}) do
        if type(mutation) == "table" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        return (tonumber(GameLib.Mutations[a].chance) or 0) < (tonumber(GameLib.Mutations[b].chance) or 0)
    end)
    return names
end

---@return string[]  unit rarities present in the registry, worst first
function GameLib.UnitRarities()
    local seen = {}
    local registry = GameLib.Entry
    if registry then
        local ok, units = pcall(registry.entriesOfKind, "Unit")
        if ok and type(units) == "table" then
            for _, config in pairs(units) do
                if type(config) == "table" and config.rarity then seen[config.rarity] = true end
            end
        end
    end
    local list = {}
    for rarity in pairs(seen) do list[#list + 1] = rarity end
    table.sort(list, function(a, b) return GameLib.RarityOrder(a) < GameLib.RarityOrder(b) end)
    return list
end

function GameLib.ShopNames()
    local names = {}
    local shop = GameLib.Quests and GameLib.Quests.Shop
    for _, item in ipairs(type(shop) == "table" and shop or {}) do
        if type(item) == "table" and item.name and not item.gamepass then names[#names + 1] = item.name end
    end
    return names
end

Hub.Net = { Cache = {} }
local Network = ReplicatedStorage:WaitForChild("Network", Hub.Config.LoadTimeout)

---@return Instance?  remote whose name and parent match the path tail, anywhere under Network
function Hub.Net.Search(path)
    if not Network then return nil end
    local parts = string.split(path, ".")
    local name, parent = parts[#parts], parts[#parts - 1]
    for _, node in ipairs(Network:GetDescendants()) do
        if node.Name == name and (not parent or (node.Parent and node.Parent.Name == parent)) then return node end
    end
    return nil
end

---@return Instance?  remote at a dotted path under Network
function Hub.Net.Get(path)
    local cached = Hub.Net.Cache[path]
    if cached and cached.Parent then return cached end

    local remote = GameLib.Find(Network, path) or Hub.Net.Search(path)
    Hub.Net.Cache[path] = remote
    return remote
end

function Hub.Net.Fire(path, ...)
    local remote = Hub.Net.Get(path)
    if remote then remote:FireServer(...) end
end

---@return boolean, any  invoke success, server reply
function Hub.Net.Invoke(path, ...)
    local remote = Hub.Net.Get(path)
    if not remote then return false, "no remote" end
    return pcall(remote.InvokeServer, remote, ...)
end

Hub.Data = {}

---@return any  raw replicated value of a top-level profile field
function Hub.Data.Read(field)
    local client = GameLib.DataClient
    if not client then return nil end
    local ok, proxy = pcall(function() return client:get({ field }) end)
    if not ok then return nil end
    if type(proxy) == "table" then
        local okCall, value = pcall(proxy)
        if okCall then return value end
    end
    return proxy
end

function Hub.Data.Table(field)
    local value = Hub.Data.Read(field)
    return type(value) == "table" and value or {}
end

function Hub.Data.Money()
    return tonumber(Hub.Data.Read("Money")) or 0
end

function Hub.Data.Rebirth()
    return tonumber(Hub.Data.Read("Rebirth")) or 0
end

function Hub.Data.Rolls()
    return tonumber(Hub.Data.Read("Rolls")) or 0
end

function Hub.Data.Token(name)
    local total = 0
    for _, entry in pairs(Hub.Data.Table("Inventory")) do
        if type(entry) == "table" and entry.name == name then
            total += tonumber(entry.amount) or 0
        end
    end
    return total
end

---@return table<string, boolean>  unit keys placed on the plot or in the tower team
function Hub.Data.BusyKeys()
    local busy = {}
    for _, slot in pairs(Hub.Data.Table("Slots")) do
        if type(slot) == "table" and slot.unitId then busy[tostring(slot.unitId)] = true end
    end
    for _, key in pairs(Hub.Data.Table("TowerTeam")) do
        if type(key) == "string" then busy[key] = true end
    end
    return busy
end

---@return table[]  items of one kind {Key, Name, Amount}
function Hub.Data.ItemsOfKind(kind)
    local items = {}
    for key, entry in pairs(Hub.Data.Table("Inventory")) do
        if type(entry) == "table" and entry.name then
            local config = GameLib.EntryOf(entry.name)
            if config and config.kind == kind then
                items[#items + 1] = { Key = tostring(key), Name = entry.name, Amount = tonumber(entry.amount) or 1 }
            end
        end
    end
    return items
end

---@return number  unit entries the server counts against Unit Storage, trade reservations included
function Hub.Data.UnitCount()
    local count = 0
    for _, entry in pairs(Hub.Data.Table("Inventory")) do
        local config = type(entry) == "table" and entry.name and GameLib.EntryOf(entry.name)
        if config and config.kind == "Unit" then count += 1 end
    end
    local trade = Hub.Data.Read("PendingTrade")
    if type(trade) == "table" and not trade.applied then count += tonumber(trade.reservedUnits) or 0 end
    return count
end

Hub.Data.UnitCache = { At = -1, List = {} }

---@return table[]  owned units, plotted first then by income; shared snapshot
function Hub.Data.Units()
    local cache = Hub.Data.UnitCache
    local now = osClock()
    if now - cache.At < Hub.Config.SnapshotTtl then return cache.List end
    cache.List = Hub.Data.ScanUnits()
    cache.At = now
    return cache.List
end

function Hub.Data.Invalidate()
    Hub.Data.UnitCache.At = -1
end

function Hub.Data.IncomeAt(config, attrs, level)
    local probe = table.clone(attrs)
    probe.level = level
    local ok, value = pcall(config.income, probe)
    return ok and tonumber(value) or 0
end

function Hub.Data.LevelPrice(unit, level)
    local probe = table.clone(unit.Attr)
    probe.level = level
    local ok, price = pcall(GameLib.UnitUtil.GetLevelPrice, unit.Name, probe)
    return ok and tonumber(price) or math.huge
end

function Hub.Data.ScanUnits()
    local busy = Hub.Data.BusyKeys()
    local units = {}
    for key, entry in pairs(Hub.Data.Table("Inventory")) do
        if type(entry) == "table" and entry.name then
            local config = GameLib.EntryOf(entry.name)
            if config and config.kind == "Unit" then
                local attrs = type(entry.attributes) == "table" and entry.attributes or {}
                local rarity = config.rarity
                if type(config.getRarity) == "function" then
                    local ok, dynamic = pcall(config.getRarity, attrs)
                    if ok and dynamic then rarity = dynamic end
                end
                local income, potential = 0, 0
                if type(config.income) == "function" then
                    local ok, value = pcall(config.income, attrs)
                    if ok then income = tonumber(value) or 0 end
                    potential = Hub.Data.IncomeAt(config, attrs, 1)
                end
                local chance
                if type(config.chance) == "function" and not config.limited and (tonumber(entry.amount) or 1) == 1 then
                    local ok, value = pcall(config.chance, attrs)
                    chance = ok and tonumber(value) or nil
                end
                key = tostring(key)
                units[#units + 1] = {
                    Key = key,
                    Name = entry.name,
                    Attr = attrs,
                    Rarity = rarity,
                    Grade = attrs.grade,
                    Trait = attrs.trait,
                    Mutation = attrs.mutation,
                    Level = tonumber(attrs.level) or 1,
                    Locked = attrs.locked == true,
                    Busy = busy[key] == true,
                    Value = income,
                    Potential = potential,
                    Chance = chance,
                }
            end
        end
    end
    table.sort(units, function(a, b)
        if a.Busy ~= b.Busy then return a.Busy end
        return a.Value > b.Value
    end)
    return units
end

Hub.Player = { Client = LocalPlayer }

function Hub.Player:Bind(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid", Hub.Config.LoadTimeout)
    self.Root = character:WaitForChild("HumanoidRootPart", Hub.Config.LoadTimeout)
end

Hub.Scheduler = { Jobs = {}, Booted = false }

---@param interval number|function  seconds, or a getter read every tick
---@param toggles string[]?          options switched off when the job keeps failing
function Hub.Scheduler.Every(name, interval, fn, toggles)
    Hub.Scheduler.Jobs[name] = { Interval = interval, Fn = fn, Last = 0, Running = false, Fails = 0, Toggles = toggles or {} }
end

---@return boolean  one of the job's toggles is on
function Hub.Scheduler.Wanted(job)
    for _, idx in ipairs(job.Toggles) do
        if Hub.Options[idx] == true then return true end
    end
    return false
end

function Hub.Scheduler.Run(name, job)
    local ok, err = pcall(job.Fn)
    job.Running = false
    if ok then
        job.Fails, job.FailSince = 0, nil
        return
    end

    job.Fails += 1
    job.FailSince = job.FailSince or osClock()
    if job.Fails == 1 then warn("[AnimeDice] job " .. name .. " failing:", err) end

    local config = Hub.Config
    if job.Fails < config.JobFailLimit or osClock() - job.FailSince < config.JobFailWindow then return end
    if not Hub.Scheduler.Wanted(job) then return end
    job.Halted = true
    table.insert(Hub.State.Halted, { name, job.Toggles, tostring(err):match("^[^\n]*") })
end

function Hub.Scheduler.Step()
    local now = osClock()
    for name, job in pairs(Hub.Scheduler.Jobs) do
        local interval = type(job.Interval) == "function" and job.Interval() or job.Interval
        if not job.Running and not job.Halted and now - job.Last >= interval then
            job.Last = now
            job.Running = true
            task.spawn(Hub.Scheduler.Run, name, job)
        end
    end
end

function Hub.Scheduler.Resume(idx)
    for _, job in pairs(Hub.Scheduler.Jobs) do
        if table.find(job.Toggles, idx) then
            job.Halted, job.Fails, job.FailSince = false, 0, nil
        end
    end
end

function Hub.Scheduler.Boot()
    if Hub.Scheduler.Booted then return end
    Hub.Scheduler.Booted = true
    Hub:Connect(RunService.Heartbeat, Hub.Scheduler.Step)
end

Hub.AntiAfk = { Connection = nil }

function Hub.AntiAfk.OnIdled()
    if not Hub.Options.AntiAfk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero)
end

function Hub.AntiAfk.Start()
    Hub.Options.AntiAfk = true
    if not Hub.AntiAfk.Connection then
        Hub.AntiAfk.Connection = Hub:Connect(LocalPlayer.Idled, Hub.AntiAfk.OnIdled)
    end
end

function Hub.AntiAfk.Stop()
    Hub.Options.AntiAfk = false
end

Hub.Cutscene = { Saved = nil }

function Hub.Cutscene.Skip() end

function Hub.Cutscene.Apply()
    local controller = GameLib.RollController
    if type(controller) ~= "table" or table.isfrozen(controller) or Hub.Cutscene.Saved then return end
    local original = rawget(controller, "PlayCutscene")
    if type(original) ~= "function" then return end
    Hub.Cutscene.Saved = original
    rawset(controller, "PlayCutscene", Hub.Cutscene.Skip)
end

function Hub.Cutscene.Restore()
    local controller = GameLib.RollController
    local original = Hub.Cutscene.Saved
    if not original then return end
    if rawget(controller, "PlayCutscene") == Hub.Cutscene.Skip then rawset(controller, "PlayCutscene", original) end
    Hub.Cutscene.Saved = nil
end

function Hub.Cutscene.Step()
    if Hub.Options.DisableCutscene then Hub.Cutscene.Apply() else Hub.Cutscene.Restore() end
end

Hub.Move = { NoClipConnection = nil, FlyConnection = nil, FlyForce = nil, JumpConnection = nil }

function Hub.Move.ApplyWalkSpeed()
    local hum = Hub.Player.Humanoid
    if hum and Hub.Options.WalkSpeed then hum.WalkSpeed = Hub.Options.WalkSpeedValue end
end

function Hub.Move.SpeedStart()
    Hub.Options.WalkSpeed = true
    Hub.Move.ApplyWalkSpeed()
end

function Hub.Move.SpeedStop()
    Hub.Options.WalkSpeed = false
    local hum = Hub.Player.Humanoid
    if hum then hum.WalkSpeed = 16 end
end

function Hub.Move.JumpStart()
    Hub.Options.InfiniteJump = true
    if Hub.Move.JumpConnection then return end
    Hub.Move.JumpConnection = Hub:Connect(UserInputService.JumpRequest, function()
        local hum = Hub.Player.Humanoid
        if Hub.Options.InfiniteJump and hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

function Hub.Move.JumpStop()
    Hub.Options.InfiniteJump = false
end

function Hub.Move.NoClipStart()
    Hub.Options.NoClip = true
    if Hub.Move.NoClipConnection then return end
    Hub.Move.NoClipConnection = Hub:Connect(RunService.Stepped, function()
        local char = Hub.Player.Character
        if not (Hub.Options.NoClip and char) then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end)
end

function Hub.Move.NoClipStop()
    Hub.Options.NoClip = false
    local char = Hub.Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CanCollide = true end
end

function Hub.Move.FlyStart()
    if Hub.Move.FlyForce then return end
    local hrp = Hub.Player.Root
    if not hrp then return end
    Hub.Options.Fly = true

    local force = Instance.new("BodyVelocity")
    force.MaxForce = Vector3.one * 9e9
    force.Velocity = Vector3.zero
    force.Parent = hrp
    Hub.Move.FlyForce = force

    if Hub.Move.FlyConnection then return end
    Hub.Move.FlyConnection = Hub:Connect(RunService.RenderStepped, function()
        local bv = Hub.Move.FlyForce
        if not (Hub.Options.Fly and bv) then return end
        local look = Workspace.CurrentCamera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * Hub.Options.FlySpeed or Vector3.zero
    end)
end

function Hub.Move.FlyStop()
    Hub.Options.Fly = false
    if Hub.Move.FlyForce then
        Hub.Move.FlyForce:Destroy()
        Hub.Move.FlyForce = nil
    end
end

function Hub.Move.Rebind()
    Hub.Move.ApplyWalkSpeed()
    if Hub.Options.Fly then
        Hub.Move.FlyForce = nil
        Hub.Move.FlyStart()
    end
end

Hub.Roll = { Status = "Off", Session = 0, LastRolls = nil, StorageFull = false, NextAt = 0 }

---@return number  seconds the server holds a roll back after an accepted one
function Hub.Roll.Duration()
    local buffs = GameLib.Buffs
    if not buffs then return 0 end
    local ok, duration = pcall(buffs.GetBuff, "Roll Duration")
    return ok and tonumber(duration) or 0
end

---@return boolean, number, number  room left for a roll, units held, units the server allows
function Hub.Roll.Room()
    local buffs = GameLib.Buffs
    if not buffs then return true, 0, 0 end
    local okStorage, storage = pcall(buffs.GetBuff, "Unit Storage")
    local okRolls, rolls = pcall(buffs.GetBuff, "Rolls")
    storage, rolls = tonumber(okStorage and storage), tonumber(okRolls and rolls)
    if not storage or not rolls then return true, 0, 0 end
    local limit = storage + rolls - 1
    local held = Hub.Data.UnitCount()
    return held < limit, held, limit
end

function Hub.Roll.SetStorageFull(full, held, limit)
    if full == Hub.Roll.StorageFull then return end
    Hub.Roll.StorageFull = full
    if not full then return end
    table.insert(Hub.State.Notices, {
        "Unit storage full",
        string.format("%d/%d units. Rolling paused until you sell or clear some.", held, limit),
    })
end

function Hub.Roll.Once()
    return Hub.Net.Invoke("RollService.RF.RollDice")
end

function Hub.Roll.ResetCounter()
    Hub.Roll.Session = 0
    Hub.Roll.LastRolls = Hub.Data.Rolls()
end

function Hub.Roll.Track()
    local rolls = Hub.Data.Rolls()
    if Hub.Roll.LastRolls and rolls > Hub.Roll.LastRolls then
        Hub.Roll.Session += rolls - Hub.Roll.LastRolls
    end
    Hub.Roll.LastRolls = rolls
end

function Hub.Roll.Step()
    Hub.Roll.Track()
    if not Hub.Options.AutoRoll then
        Hub.Roll.Status = "Off"
        Hub.Roll.StorageFull = false
        return
    end
    local hasRoom, held, limit = Hub.Roll.Room()
    Hub.Roll.SetStorageFull(not hasRoom, held, limit)
    if not hasRoom then
        Hub.Roll.Status = string.format("Storage full %d/%d, paused", held, limit)
        return
    end
    Hub.Roll.Status = "Rolling"
    if osClock() < Hub.Roll.NextAt then return end
    local ok, reply = Hub.Roll.Once()
    if ok and reply ~= nil then
        Hub.Roll.NextAt = osClock() + math.max(Hub.Roll.Duration() - Hub.Config.RollLead, 0)
    end
end

function Hub.Roll.GetStatus()
    return string.format("%s · session %s · total %s", Hub.Roll.Status,
        Util.FormatNumber(Hub.Roll.Session), Util.FormatNumber(Hub.Data.Rolls()))
end

Hub.Plot = { Status = "Off" }

function Hub.Plot.CollectNow()
    for index, slot in pairs(Hub.Data.Table("Slots")) do
        local balance = type(slot) == "table" and tonumber(slot.balance) or 0
        if balance > 0 then
            Hub.Net.Fire("PlotService.RE.CollectBalance", tonumber(index))
            Hub.Economy.Collected += balance
        end
    end
end

---@return number  highest level whose price still pays back within the payback limit
function Hub.Plot.WorthLevel(unit, mult)
    local config = GameLib.EntryOf(unit.Name)
    if not config then return unit.Level end
    local gain = (Hub.Data.IncomeAt(config, unit.Attr, 2) - unit.Potential) * mult
    if gain <= 0 then return unit.Level end
    local cap = math.min(Hub.Options.LevelTarget, 500)
    local level = 1
    while level < cap and Hub.Data.LevelPrice(unit, level) / gain <= Hub.Options.LevelPayback do
        level += 1
    end
    return level
end

---@return number  income this unit reaches on the plot once cheap levels are bought
function Hub.Plot.Score(unit, mult)
    local config = GameLib.EntryOf(unit.Name)
    if not config then return unit.Value end
    local level = math.max(unit.Level, Hub.Plot.WorthLevel(unit, mult))
    return level == unit.Level and unit.Value or Hub.Data.IncomeAt(config, unit.Attr, level)
end

---@return table[]  { slot, placeKey } swaps that raise plot income, weakest slot first
function Hub.Plot.PlanSwaps()
    local slots = Hub.Data.Table("Slots")
    local byKey = {}
    for _, unit in ipairs(Hub.Data.Units()) do byKey[unit.Key] = unit end

    local mult = Hub.Economy.Multiplier()
    local current, placed = {}, {}
    for index, slot in pairs(slots) do
        if type(slot) ~= "table" then continue end
        local unit = slot.unitId and byKey[tostring(slot.unitId)]
        current[#current + 1] = { tonumber(index), unit and Hub.Plot.Score(unit, mult) or 0 }
        if unit then placed[unit.Key] = true end
    end
    table.sort(current, function(a, b) return a[2] < b[2] end)

    local bench = {}
    for _, unit in ipairs(Hub.Data.Units()) do
        if not placed[unit.Key] then bench[#bench + 1] = unit end
    end
    table.sort(bench, function(a, b) return a.Potential > b.Potential end)
    for index = #bench, #current * 2 + 1, -1 do bench[index] = nil end
    for _, unit in ipairs(bench) do unit.Score = Hub.Plot.Score(unit, mult) end
    table.sort(bench, function(a, b) return a.Score > b.Score end)

    local swaps = {}
    for index, slot in ipairs(current) do
        local candidate = bench[index]
        if not candidate or candidate.Score < slot[2] * Hub.Config.SwapMargin then break end
        swaps[#swaps + 1] = { slot[1], candidate.Key }
    end
    return swaps
end

---@return number  units moved onto the plot
function Hub.Plot.EquipBest()
    if Hub.Options.PlacementMode ~= "Potential" then
        Hub.Net.Fire("PlotService.RE.EquipBest")
        return 0
    end
    local moved = 0
    for _, swap in ipairs(Hub.Plot.PlanSwaps()) do
        if moved >= Hub.Config.SwapsPerPass then break end
        Hub.Net.Fire("PlotService.RE.CollectBalance", swap[1])
        local ok, held = Hub.Net.Invoke("UnitService.RF.Equip", swap[2])
        if not (ok and held) then break end
        task.wait(Hub.Config.PlaceDelay)
        Hub.Net.Fire("PlotService.RE.InteractSlot", swap[1])
        moved += 1
        task.wait(Hub.Config.PlaceDelay)
    end
    if moved > 0 then Hub.Data.Invalidate() end
    Hub.Plot.Status = moved > 0 and (moved .. " better units placed") or "Best units placed"
    return moved
end

function Hub.Plot.CollectStep()
    if Hub.Options.AutoCollect then Hub.Plot.CollectNow() end
end

function Hub.Plot.EquipStep()
    if Hub.Options.EquipBestUnitsAuto then Hub.Plot.EquipBest() end
end

---@return table[]  { slot, price, payback } for plotted units, fastest payback first
function Hub.Plot.LevelCandidates()
    local byKey = {}
    for _, unit in ipairs(Hub.Data.Units()) do byKey[unit.Key] = unit end
    local minRarity = GameLib.RarityOrder(Hub.Options.LevelMinRarity)
    local mult = Hub.Economy.Multiplier()
    local list = {}

    for index, slot in pairs(Hub.Data.Table("Slots")) do
        local unit = type(slot) == "table" and slot.unitId and byKey[tostring(slot.unitId)]
        if not unit or unit.Level >= Hub.Options.LevelTarget or GameLib.RarityOrder(unit.Rarity) < minRarity then continue end
        local config = GameLib.EntryOf(unit.Name)
        local okPrice, price = pcall(GameLib.UnitUtil.GetLevelPrice, unit.Name, unit.Attr)
        local nextAttrs = table.clone(unit.Attr)
        nextAttrs.level = unit.Level + 1
        local okGain, nextIncome = pcall(config.income, nextAttrs)
        local gain = okGain and ((tonumber(nextIncome) or 0) - unit.Value) * mult or 0
        if okPrice and tonumber(price) and gain > 0 then
            list[#list + 1] = { tonumber(index), price, price / gain }
        end
    end
    table.sort(list, function(a, b) return a[3] < b[3] end)
    return list
end

---@param ignoreGoal boolean?  manual pass: skip saving for dice/rebirth
---@return number  levels bought
function Hub.Plot.LevelPass(ignoreGoal)
    local money = Hub.Data.Money()
    local goal = not ignoreGoal and Hub.Economy.Goal()
    local levelled = 0

    for _, pick in ipairs(Hub.Plot.LevelCandidates()) do
        local slot, price, payback = pick[1], pick[2], pick[3]
        if payback > Hub.Options.LevelPayback then break end
        if price > money then continue end
        if goal and money - price < goal.Cost and payback >= Hub.Economy.Eta(goal.Cost, money - price) then continue end
        Hub.Net.Fire("PlotService.RE.LevelUpSlot", slot)
        money -= price
        levelled += 1
        task.wait(Hub.Config.LevelDelay)
    end
    Hub.Plot.Status = levelled > 0 and (levelled .. " levelled") or (goal and ("Saving for " .. goal.Name) or "No level worth it")
    return levelled
end

Hub.Economy = { Rate = 0, Collected = 0, LastTotal = nil, LastAt = 0, Earned = 0 }

function Hub.Economy.Sample()
    local total = 0
    for _, slot in pairs(Hub.Data.Table("Slots")) do
        if type(slot) == "table" then total += tonumber(slot.balance) or 0 end
    end
    local economy, now = Hub.Economy, osClock()
    if economy.LastTotal and now > economy.LastAt then
        local earned = total + economy.Collected - economy.LastTotal
        local sample = earned / (now - economy.LastAt)
        if sample >= 0 then
            economy.Rate = economy.Rate == 0 and sample or economy.Rate * 0.8 + sample * 0.2
            economy.Earned += earned
        end
    end
    economy.LastTotal, economy.LastAt, economy.Collected = total, now, 0
end

---@return number  real money per second divided by the plotted units' raw income
function Hub.Economy.Multiplier()
    local plotted = {}
    for _, slot in pairs(Hub.Data.Table("Slots")) do
        if type(slot) == "table" and slot.unitId then plotted[tostring(slot.unitId)] = true end
    end
    local raw = 0
    for _, unit in ipairs(Hub.Data.Units()) do
        if plotted[unit.Key] then raw += unit.Value end
    end
    return (raw > 0 and Hub.Economy.Rate > 0) and Hub.Economy.Rate / raw or 1
end

---@return table?  cheapest enabled goal {Name, Cost} still out of reach
function Hub.Economy.Goal()
    local goals = {}
    if Hub.Options.AutoRebirth then
        local rebirth = Hub.Rebirth.Next()
        if rebirth then goals[#goals + 1] = { Name = "rebirth", Cost = tonumber(rebirth.cost) or math.huge } end
    end
    if Hub.Options.AutoBuyDice then
        local name, price = Hub.Dice.NextTarget()
        if name then goals[#goals + 1] = { Name = name .. " dice", Cost = price } end
    end
    table.sort(goals, function(a, b) return a.Cost < b.Cost end)
    return goals[1]
end

function Hub.Economy.Eta(cost, money)
    local rate = Hub.Economy.Rate
    if cost <= money then return 0 end
    return rate > 0 and (cost - money) / rate or math.huge
end

function Hub.Economy.Step()
    Hub.Economy.Sample()
    local options = Hub.Options
    if options.AutoBuyDice or options.AutoEquipBestDice then Hub.Dice.Step() end
    if options.AutoRebirth then Hub.Rebirth.RebirthNow() end
    if options.AutoRebirthStats then Hub.Rebirth.SpendPoints() end
    if options.AutoBuyUpgrades then Hub.Upgrade.BuyAll() end
    if options.AutoLevelUp then Hub.Plot.LevelPass() end
end

function Hub.Economy.GetStatus()
    local goal = Hub.Economy.Goal()
    local text = "Income " .. Util.FormatNumber(Hub.Economy.Rate) .. "/s"
    if not goal then return text end
    local eta = Hub.Economy.Eta(goal.Cost, Hub.Data.Money())
    local etaText = eta == math.huge and "?" or (eta < 60 and string.format("%ds", eta) or string.format("%dm", math.floor(eta / 60)))
    return string.format("%s · %s in %s", text, goal.Name, etaText)
end

Hub.Dice = { Status = "Off" }

---@return string, number  free starter dice (cheapest in the shop) and its luck
function Hub.Dice.Starter()
    local name, price, luck = "Basic", math.huge, 1
    for diceName, info in pairs(GameLib.Dice and GameLib.Dice.GetAll() or {}) do
        local cost = tonumber(info.price) or 0
        if cost < price then name, price, luck = diceName, cost, tonumber(info.luck) or 1 end
    end
    return name, luck
end

function Hub.Dice.OwnedSet()
    local owned = { [Hub.Dice.Starter()] = true }
    for key, value in pairs(Hub.Data.Table("OwnedDice")) do
        if type(key) == "number" then owned[value] = true elseif value then owned[key] = true end
    end
    return owned
end

---@return string, number  best owned dice and its luck
function Hub.Dice.BestOwned()
    local owned = Hub.Dice.OwnedSet()
    local bestName, bestLuck = Hub.Dice.Starter()
    for name, info in pairs(GameLib.Dice and GameLib.Dice.GetAll() or {}) do
        local luck = tonumber(info.luck) or 0
        if owned[name] and luck > bestLuck then bestName, bestLuck = name, luck end
    end
    return bestName, bestLuck
end

---@return string?  highest-luck dice affordable now that beats the best owned
function Hub.Dice.NextBuy()
    local owned = Hub.Dice.OwnedSet()
    local money = Hub.Data.Money()
    local _, pickLuck = Hub.Dice.BestOwned()
    local pick
    for name, info in pairs(GameLib.Dice and GameLib.Dice.GetAll() or {}) do
        local luck = tonumber(info.luck) or 0
        if not owned[name] and (tonumber(info.price) or math.huge) <= money and luck > pickLuck then
            pick, pickLuck = name, luck
        end
    end
    return pick
end

---@return string?, number  cheapest unowned dice luckier than the best owned
function Hub.Dice.NextTarget()
    local owned = Hub.Dice.OwnedSet()
    local _, bestLuck = Hub.Dice.BestOwned()
    local pick, pickPrice = nil, math.huge
    for name, info in pairs(GameLib.Dice and GameLib.Dice.GetAll() or {}) do
        local price = tonumber(info.price) or math.huge
        if not owned[name] and (tonumber(info.luck) or 0) > bestLuck and price < pickPrice then pick, pickPrice = name, price end
    end
    return pick, pickPrice
end

function Hub.Dice.EquipBest()
    local best = Hub.Dice.BestOwned()
    if best ~= Hub.Data.Read("Dice") then Hub.Net.Fire("DiceShopService.RE.EquipDice", best) end
end

function Hub.Dice.Step()
    if Hub.Options.AutoBuyDice then
        local buy = Hub.Dice.NextBuy()
        if buy then
            Hub.Net.Fire("DiceShopService.RE.BuyDice", buy)
            Hub.Dice.Status = "Bought " .. buy
            task.wait(Hub.Config.BuyDelay)
        end
    end
    if Hub.Options.AutoEquipBestDice or Hub.Options.AutoBuyDice then Hub.Dice.EquipBest() end
end

Hub.Upgrade = { Status = "Off" }

function Hub.Upgrade.Branch(name)
    return (name:gsub("%s+[IVXLC]+$", ""))
end

function Hub.Upgrade.Branches()
    local seen = {}
    for name in pairs(GameLib.Upgrades or {}) do
        if type(name) == "string" and name ~= "Start" then seen[Hub.Upgrade.Branch(name)] = true end
    end
    return Util.SortedKeys(seen)
end

---@return table  stat -> { base, percentage } summed over owned upgrades
function Hub.Upgrade.OwnedBuffs(owned)
    local sums = {}
    for name in pairs(owned) do
        local info = GameLib.Upgrades and GameLib.Upgrades[name]
        for stat, buff in pairs(type(info) == "table" and info.buffs or {}) do
            sums[stat] = sums[stat] or { base = 0, percentage = 0 }
            if sums[stat][buff.bucket] then sums[stat][buff.bucket] += tonumber(buff.amount) or 0 end
        end
    end
    return sums
end

---@return number  relative boost this buff adds to its stat (0.1 = +10%)
function Hub.Upgrade.Gain(stat, buff, sums)
    local amount = tonumber(buff.amount) or 0
    local sum = sums[stat] or { base = 0, percentage = 0 }
    if stat == "Roll Duration" then
        local ok, duration = pcall(GameLib.Buffs.GetBuff, stat)
        duration = ok and tonumber(duration) or 0
        return duration + amount > 0 and duration / (duration + amount) - 1 or 0
    end
    if buff.bucket == "percentage" then return amount / (1 + sum.percentage) end
    if buff.bucket == "multiplier" then return amount - 1 end
    local ok, config = pcall(GameLib.BuffsConfig.GetBuff, stat)
    local default = ok and type(config) == "table" and tonumber(config.default) or 1
    return amount / math.max(default + sum.base, 1e-3)
end

---@return number?  money spent per +1% luck on the next dice, nil when dice are maxed
function Hub.Upgrade.DiceDeal()
    local name, price = Hub.Dice.NextTarget()
    if not name then return nil end
    local _, bestLuck = Hub.Dice.BestOwned()
    local luck = tonumber(GameLib.Dice.GetAll()[name].luck) or bestLuck
    return price / math.max(luck / bestLuck - 1, 1e-3)
end

---@return boolean  price is a small slice of what the player earns
function Hub.Upgrade.Cheap(stat, price, money, rate)
    local seconds = Hub.Config.UtilitySeconds
    if rate > 0 then return price <= rate * (seconds[stat] or seconds.Default) end
    return price <= money * Hub.Config.UtilityFallbackShare
end

---@return table[]  { name, price, rank } upgrades worth buying now, best first
function Hub.Upgrade.Worth()
    local owned = Hub.Data.Table("Upgrades")
    local sums = Hub.Upgrade.OwnedBuffs(owned)
    local money, rate = Hub.Data.Money(), Hub.Economy.Rate
    local goal = Hub.Economy.Goal()
    local diceDeal = Hub.Upgrade.DiceDeal()
    local filter = Util.SetFromList(Hub.Options.UpgradeFilter)
    local anyBranch = next(filter) == nil
    local tree = GameLib.Tree
    local picks = {}

    for name, info in pairs(GameLib.Upgrades or {}) do
        if type(info) ~= "table" or name == "Start" or owned[name] then continue end
        local price = tonumber(info.price) or math.huge
        if price > money or not (anyBranch or filter[Hub.Upgrade.Branch(name)]) then continue end
        local parent = tree.GetParent(name)
        if parent and parent ~= "Start" and not owned[parent] then continue end

        local rank
        for stat, buff in pairs(info.buffs or {}) do
            local gain = Hub.Upgrade.Gain(stat, buff, sums)
            if gain <= 0 then continue end
            if stat == "Money Multiplier" and rate > 0 then
                local payback = price / (rate * gain)
                local etaAfter = goal and Hub.Economy.Eta(goal.Cost, money - price) or math.huge
                if payback <= Hub.Options.UpgradePayback or payback < etaAfter then rank = payback end
            elseif Hub.Config.RollStats[stat] and diceDeal then
                if price / (gain * 100) <= diceDeal / 100 then rank = 1e6 + price / money end
            elseif Hub.Upgrade.Cheap(stat, price, money, rate) then
                rank = 2e6 + price / money
            end
        end
        if rank then picks[#picks + 1] = { name, price, rank } end
    end
    table.sort(picks, function(a, b) return a[3] < b[3] end)
    return picks
end

---@return string  cheapest upgrade still locked behind money
function Hub.Upgrade.NextHint()
    local owned = Hub.Data.Table("Upgrades")
    local pick, price = nil, math.huge
    for name, info in pairs(GameLib.Upgrades or {}) do
        if type(info) ~= "table" or name == "Start" or owned[name] then continue end
        local parent = GameLib.Tree.GetParent(name)
        if parent and parent ~= "Start" and not owned[parent] then continue end
        if (tonumber(info.price) or math.huge) < price then pick, price = name, tonumber(info.price) end
    end
    return pick and string.format("Next: %s at %s", pick, Util.FormatNumber(price)) or "All upgrades owned"
end

---@return number  upgrades bought
function Hub.Upgrade.BuyAll()
    local bought, spent = 0, 0
    for _, pick in ipairs(Hub.Upgrade.Worth()) do
        if pick[2] + spent > Hub.Data.Money() then continue end
        Hub.Net.Fire("RE.BuyUpgrade", pick[1])
        spent += pick[2]
        bought += 1
        task.wait(Hub.Config.BuyDelay)
    end
    Hub.Upgrade.Status = bought > 0 and (bought .. " bought") or Hub.Upgrade.NextHint()
    return bought
end

Hub.Sell = { Status = "Off" }

---@return string[]  unit keys to sell under the current filters
function Hub.Sell.Pick()
    local wanted = Util.SetFromList(Hub.Options.SellRarities)
    if next(wanted) == nil then return {} end
    local keepMutation = Util.SetFromList(Hub.Options.SellKeepMutations)
    local keep = math.max(Hub.Options.KeepPerRarity, 0)

    local byRarity = {}
    for _, unit in ipairs(Hub.Data.Units()) do
        if unit.Busy or unit.Locked or not wanted[unit.Rarity] then continue end
        if unit.Mutation and keepMutation[unit.Mutation] then continue end
        byRarity[unit.Rarity] = byRarity[unit.Rarity] or {}
        table.insert(byRarity[unit.Rarity], unit)
    end

    local keys = {}
    for _, list in pairs(byRarity) do
        for index = keep + 1, #list do keys[#keys + 1] = list[index].Key end
    end
    return keys
end

function Hub.Sell.SellNow()
    local keys = Hub.Sell.Pick()
    if #keys == 0 then Hub.Sell.Status = "Nothing to sell" return Hub.Sell.Status end
    local before = Hub.Data.Money()
    Hub.Net.Invoke("SellService.RF.SellInventory", keys)
    Hub.Data.Invalidate()
    Hub.Sell.Status = string.format("%d sold (+%s)", #keys, Util.FormatNumber(Hub.Data.Money() - before))
    return Hub.Sell.Status
end

function Hub.Sell.Step()
    if Hub.Options.AutoSell then Hub.Sell.SellNow() end
end

Hub.Storage = { Status = "-" }

function Hub.Storage.Cap()
    local buffs = GameLib.Buffs
    local ok, cap = pcall(function() return buffs.GetBuff("Unit Storage") end)
    return ok and tonumber(cap) or math.huge
end

---@return number  units sold to make room for rolling
function Hub.Storage.Clear()
    local units = Hub.Data.Units()
    local cap = Hub.Storage.Cap()
    Hub.Storage.Status = string.format("%d/%s", #units, cap == math.huge and "?" or tostring(cap))
    if #units < cap - Hub.Config.StorageHeadroom then return 0 end

    local keepRank = GameLib.RarityOrder(Hub.Options.ClearKeepRarity)
    local keepMutation = Util.SetFromList(Hub.Options.SellKeepMutations)
    local spare = {}
    for _, unit in ipairs(units) do
        if unit.Busy or unit.Locked or (unit.Mutation and keepMutation[unit.Mutation]) then continue end
        if keepRank > 0 and GameLib.RarityOrder(unit.Rarity) >= keepRank then continue end
        spare[#spare + 1] = unit
    end
    table.sort(spare, function(a, b) return a.Potential < b.Potential end)

    local excess = #units - math.floor(cap * Hub.Config.StorageRefill)
    local keys = {}
    for index = 1, math.min(excess, #spare) do keys[index] = spare[index].Key end
    if #keys == 0 then Hub.Storage.Status ..= " · full, nothing sellable" return 0 end

    Hub.Net.Invoke("SellService.RF.SellInventory", keys)
    Hub.Data.Invalidate()
    return #keys
end

function Hub.Storage.Step()
    if Hub.Options.AutoClearStorage then Hub.Storage.Clear() end
end

Hub.Rebirth = { Status = "Off" }

---@return table?  next tier {cost, moneyMultiplier}, nil at max
function Hub.Rebirth.Next()
    local rebirths = GameLib.Rebirths
    if not rebirths then return nil end
    local ok, info = pcall(rebirths.GetNext, Hub.Data.Rebirth())
    return ok and type(info) == "table" and info or nil
end

function Hub.Rebirth.RebirthNow()
    local info = Hub.Rebirth.Next()
    if not info then Hub.Rebirth.Status = "Max rebirth" return false end
    if Hub.Data.Money() < (tonumber(info.cost) or math.huge) then
        Hub.Rebirth.Status = "Need " .. Util.FormatNumber(info.cost)
        return false
    end
    Hub.Net.Fire("RebirthService.RE.Rebirth")
    Hub.Rebirth.Status = "Rebirthed"
    return true
end

function Hub.Rebirth.PointsLeft()
    local config = GameLib.RebirthStats
    if not config then return 0 end
    local ok, left = pcall(config.GetRemaining, Hub.Data.Rebirth(), Hub.Data.Table("RebirthStats"))
    return ok and tonumber(left) or 0
end

---@return number  points spent
function Hub.Rebirth.SpendPoints()
    local stat = Hub.Options.RebirthStat
    local spent = 0
    while Hub.Rebirth.PointsLeft() > 0 and spent < 200 do
        local before = Hub.Rebirth.PointsLeft()
        Hub.Net.Fire("RebirthService.RE.AddStat", stat)
        task.wait(Hub.Config.StatDelay)
        if Hub.Rebirth.PointsLeft() >= before then
            task.wait(Hub.Config.StatDelay * 3)
            if Hub.Rebirth.PointsLeft() >= before then break end
        end
        spent += 1
    end
    return spent
end

---@return boolean, string?  false and why when the reset can't run
function Hub.Rebirth.ResetStats()
    local config = GameLib.RebirthStats
    if not config then return false, "Stats not found" end
    if config.GetSpent(Hub.Data.Table("RebirthStats")) <= 0 then return false, "No points spent" end
    if Hub.Data.Token("Reset Token") < 1 then return false, "No Reset Token" end
    Hub.Net.Fire("RebirthService.RE.UseResetToken")
    return true
end

Hub.Grade = { Status = "Off" }

---@return table?  next unit that should be rerolled toward the target
function Hub.Grade.Pick()
    local target = GameLib.GradeOrder(Hub.Options.GradeTarget)
    local protected = Hub.Data.Table("ProtectedGrades")
    for _, unit in ipairs(Hub.Data.Units()) do
        if not unit.Busy or unit.Locked or GameLib.GradeOrder(unit.Grade) >= target then continue end
        if unit.Grade and protected[unit.Grade] and not Hub.Options.GradeOverwrite then continue end
        return unit
    end
    return nil
end

function Hub.Grade.RollOne()
    if Hub.Data.Token("Gems") < 1 then Hub.Grade.Status = "No Gems" return false end
    local unit = Hub.Grade.Pick()
    if not unit then Hub.Grade.Status = "All at target" return false end
    Hub.Net.Fire("GradeService.RE.Roll", unit.Key)
    Hub.Grade.Status = string.format("%s [%s]", unit.Name, unit.Grade or "-")
    return true
end

function Hub.Grade.Step()
    if Hub.Options.AutoGrade then Hub.Grade.RollOne() end
end

Hub.Trait = { Status = "Off" }

function Hub.Trait.Pick()
    local target = GameLib.TraitPower(Hub.Options.TraitTarget)
    local protected = Hub.Data.Table("ProtectedTraits")
    for _, unit in ipairs(Hub.Data.Units()) do
        if not unit.Busy or unit.Locked or GameLib.TraitPower(unit.Trait) >= target then continue end
        if unit.Trait and protected[unit.Trait] and not Hub.Options.TraitOverwrite then continue end
        return unit
    end
    return nil
end

function Hub.Trait.RollOne()
    if Hub.Data.Token("Trait Reroll") < 1 then Hub.Trait.Status = "No Trait Reroll" return false end
    local unit = Hub.Trait.Pick()
    if not unit then Hub.Trait.Status = "All at target" return false end
    Hub.Net.Fire("TraitService.RE.Roll", unit.Key)
    Hub.Trait.Status = string.format("%s [%s]", unit.Name, unit.Trait or "-")
    return true
end

function Hub.Trait.Step()
    if Hub.Options.AutoTrait then Hub.Trait.RollOne() end
end

Hub.Fuse = { Status = "Off" }

---@return table[]  spare units the game allows to fuse, rarest first
function Hub.Fuse.Pool()
    local wanted = Util.SetFromList(Hub.Options.FuseRarities)
    local anyRarity = next(wanted) == nil
    local keepRank = GameLib.RarityOrder(Hub.Options.ClearKeepRarity)
    local keepMutation = Util.SetFromList(Hub.Options.SellKeepMutations)
    local pool = {}
    for _, unit in ipairs(Hub.Data.Units()) do
        if unit.Busy or unit.Locked or not unit.Chance then continue end
        if unit.Mutation and keepMutation[unit.Mutation] then continue end
        if anyRarity and keepRank > 0 and GameLib.RarityOrder(unit.Rarity) >= keepRank then continue end
        if anyRarity or wanted[unit.Rarity] then pool[#pool + 1] = unit end
    end
    table.sort(pool, function(a, b) return a.Chance > b.Chance end)
    return pool
end

---@return table?  three keys whose expected result is clearly rarer than the best input and cheap to fuse
function Hub.Fuse.PickTrio()
    local pool = Hub.Fuse.Pool()
    local config = GameLib.FusingConfig
    local average = tonumber(config.AverageMultiplier) or 0.667
    local budget = Hub.Data.Money() * Hub.Config.FuseMoneyShare
    for index = 1, #pool - 2 do
        local a, b, c = pool[index], pool[index + 1], pool[index + 2]
        local sum = a.Chance + b.Chance + c.Chance
        local ok, cost = pcall(config.GetCost, sum)
        if sum * average >= a.Chance * Hub.Config.FuseGain and ok and cost <= budget then
            return { a.Key, b.Key, c.Key, a.Name }
        end
    end
    return nil
end

function Hub.Fuse.FuseNow()
    local trio = Hub.Fuse.PickTrio()
    if not trio then Hub.Fuse.Status = "No worthwhile trio" return false end
    Hub.Net.Fire("FusingService.RE.Fuse", trio[1], trio[2], trio[3])
    Hub.Data.Invalidate()
    Hub.Fuse.Status = "Fused " .. trio[4] .. " +2"
    return true
end

function Hub.Fuse.Step()
    if Hub.Options.AutoFuse then Hub.Fuse.FuseNow() end
end

Hub.Tower = { Status = "Off", State = "Idle", NextAt = 0, Floor = 0, Best = 0, Runs = 0, Misses = 0, Ending = false }

---@return string[]  "Tower (Difficulty)" labels, easiest first
function Hub.Tower.Labels()
    local towers = GameLib.Towers and GameLib.Towers.GetAll() or {}
    local names = {}
    for name in pairs(towers) do names[#names + 1] = name end
    table.sort(names, function(a, b) return (tonumber(towers[a].order) or 0) < (tonumber(towers[b].order) or 0) end)
    local labels = {}
    for _, name in ipairs(names) do
        local difficulty = type(towers[name].difficulty) == "table" and towers[name].difficulty.name or "?"
        labels[#labels + 1] = string.format("%s (%s)", name, difficulty)
    end
    return labels
end

function Hub.Tower.NameFromLabel(label)
    return (tostring(label):gsub("%s*%b()$", ""))
end

function Hub.Tower.EquipTeam()
    Hub.Net.Fire("Towers.RE.EquipBestTowerTeam")
end

---@return number  seconds the server needs to play the returned actions
function Hub.Tower.Duration(actions)
    local total = 0
    for _, action in ipairs(actions) do
        total += Hub.Config.TowerActionTime[action.action] or 0.3
    end
    return total
end

---@return string[]  tower names, easiest first
function Hub.Tower.Order()
    local towers = GameLib.Towers and GameLib.Towers.GetAll() or {}
    local names = {}
    for name in pairs(towers) do names[#names + 1] = name end
    table.sort(names, function(a, b) return (tonumber(towers[a].order) or 0) < (tonumber(towers[b].order) or 0) end)
    return names
end

---@param floor number?  floor the last run reached, nil when the tower could not be entered
function Hub.Tower.Adapt(floor)
    if not Hub.Options.TowerSmart then return end
    local order = Hub.Tower.Order()
    local index = table.find(order, Hub.Options.TowerName) or 1
    local info = GameLib.Towers.Get(Hub.Options.TowerName)
    local top = math.min(tonumber(info and info.maxFloors) or math.huge, Hub.Options.TowerStopFloor)
    if floor and floor >= top and order[index + 1] then
        index += 1
    elseif (not floor or floor < Hub.Config.TowerDemoteFloor) and index > 1 then
        index -= 1
    end
    Hub.Options.TowerName = order[index]
end

function Hub.Tower.Leave()
    if Hub.Tower.Ending then return end
    Hub.Tower.Ending = true
    Hub.Net.Invoke("Towers.RF.CancelTower")
end

function Hub.Tower.Start()
    local now = osClock()
    if Hub.Options.TowerReequip or Hub.Tower.Runs == 0 then
        Hub.Tower.EquipTeam()
        task.wait(0.4)
    end
    local _, started = Hub.Net.Invoke("Towers.RF.PlayTower", Hub.Options.TowerName)
    Hub.Tower.State = "Climbing"
    Hub.Tower.Floor = 0
    Hub.Tower.Ending = not started
    Hub.Tower.NextAt = now
    Hub.Tower.Status = started and ("Entered " .. Hub.Options.TowerName) or "Finishing previous run"
end

function Hub.Tower.Climb()
    local ok, actions = Hub.Net.Invoke("Towers.RF.CompleteTowerFloor")
    local now = osClock()
    if not ok or type(actions) ~= "table" or #actions == 0 then
        Hub.Tower.Misses += 1
        Hub.Tower.NextAt = now + Hub.Config.TowerRetry
        if Hub.Tower.Misses >= 20 then
            Hub.Tower.Misses = 0
            Hub.Tower.Adapt(nil)
            Hub.Tower.State = "Idle"
            Hub.Tower.NextAt = now + Hub.Config.TowerStartCooldown
        end
        return
    end
    Hub.Tower.Misses = 0

    for _, action in ipairs(actions) do
        if tonumber(action.floor) then Hub.Tower.Floor = math.max(Hub.Tower.Floor, action.floor) end
    end
    Hub.Tower.Best = math.max(Hub.Tower.Best, Hub.Tower.Floor)
    Hub.Tower.NextAt = now + Hub.Tower.Duration(actions)

    if actions[#actions].action == "ended" then
        Hub.Tower.Runs += 1
        Hub.Tower.State = "Idle"
        Hub.Tower.Ending = false
        Hub.Tower.NextAt += Hub.Config.TowerStartCooldown
        Hub.Tower.Status = string.format("Run %d ended at floor %d", Hub.Tower.Runs, Hub.Tower.Floor)
        Hub.Tower.Adapt(Hub.Tower.Floor)
        return
    end
    if Hub.Tower.Floor >= Hub.Options.TowerStopFloor then Hub.Tower.Leave() end
    Hub.Tower.Status = string.format("%s · floor %d", Hub.Options.TowerName, Hub.Tower.Floor)
end

function Hub.Tower.Step()
    local tower = Hub.Tower
    if osClock() < tower.NextAt then return end
    if not Hub.Options.AutoTower then
        if tower.State == "Idle" then tower.Status = "Off" return end
        tower.Leave()
        tower.Climb()
        return
    end
    if tower.State == "Idle" then tower.Start() else tower.Climb() end
end

function Hub.Tower.GetStatus()
    if not Hub.Options.AutoTower then return "Off" end
    return string.format("%s · best %d · runs %d", Hub.Tower.Status, Hub.Tower.Best, Hub.Tower.Runs)
end

Hub.Gear = { Status = "Off" }

---@return number  slots changed
function Hub.Gear.EquipBest()
    local best = {}
    for _, item in ipairs(Hub.Data.ItemsOfKind("Gear")) do
        local config = GameLib.EntryOf(item.Name)
        local slot = config and config.slot
        if not slot then continue end
        local rank = GameLib.RarityOrder(config.rarity)
        if not best[slot] or rank > best[slot][2] then best[slot] = { item.Name, rank } end
    end

    local equipped = Hub.Data.Table("EquippedGear")
    local changed = 0
    for slot, pick in pairs(best) do
        if equipped[slot] ~= pick[1] then
            Hub.Net.Fire("GearService.RE.Equip", slot, pick[1])
            changed += 1
            task.wait(Hub.Config.GradeDelay)
        end
    end
    Hub.Gear.Status = changed > 0 and (changed .. " slots upgraded") or "Best gear on"
    return changed
end

function Hub.Gear.Step()
    if Hub.Options.AutoGear then Hub.Gear.EquipBest() end
end

Hub.Items = { Status = "Off" }

---@return boolean  true while the potion's effect is actually being used
function Hub.Items.PotionUseful(name)
    local towerWord = name:match("^(%a+)%s+%a+%s+[IVX]+$")
    if towerWord then
        return Hub.Options.AutoTower and Hub.Tower.State == "Climbing" and Hub.Options.TowerName:find(towerWord) ~= nil
    end
    if name:find("Luck") then return Hub.Options.AutoRoll end
    if name:find("Damage") then return Hub.Options.AutoTower end
    if name:find("Income") then return Hub.Economy.Rate > 0 end
    return true
end

---@param force boolean?  manual use: ignore timing
function Hub.Items.UsePotions(force)
    local filter = Util.SetFromList(Hub.Options.PotionFilter)
    local anyPotion = next(filter) == nil
    local active = Hub.Data.Table("ActiveEntries")
    local used = 0
    for _, item in ipairs(Hub.Data.ItemsOfKind("Boost")) do
        if not (force or Hub.Items.PotionUseful(item.Name)) then continue end
        if (anyPotion or filter[item.Name]) and not active[item.Name] then
            Hub.Net.Fire("BoostService.RE.Use", item.Key)
            used += 1
            task.wait(Hub.Config.ItemDelay)
        end
    end
    return used
end

function Hub.Items.UseSpins()
    local used = 0
    for _, item in ipairs(Hub.Data.ItemsOfKind("Spin")) do
        for _ = 1, math.min(item.Amount, 10) do
            Hub.Net.Fire("SpinService.RE.Use", item.Key)
            used += 1
            task.wait(Hub.Config.ItemDelay)
        end
    end
    return used
end

---@return number  gamepass items redeemed
function Hub.Items.UseGamepasses()
    local owned = Hub.Data.Table("OwnedGamepasses")
    local used = 0
    for _, item in ipairs(Hub.Data.ItemsOfKind("Gamepass")) do
        local config = GameLib.EntryOf(item.Name)
        if config and config.gamepass and owned[config.gamepass] then continue end
        Hub.Net.Fire("GamepassService.RE.Use", item.Key)
        used += 1
        task.wait(Hub.Config.ItemDelay)
    end
    return used
end

---@return number  ticket shop purchases made
function Hub.Items.BuyTicketShop()
    local wanted = Util.SetFromList(Hub.Options.TicketShopItems)
    if next(wanted) == nil then return 0 end
    local shop = GameLib.Quests and GameLib.Quests.Shop or {}
    local bought = 0
    for _, item in ipairs(shop) do
        if type(item) ~= "table" or not wanted[item.name] then continue end
        local cost = tonumber(item.tickets) or math.huge
        while Hub.Data.Token("Tickets") >= cost and bought < 50 do
            local before = Hub.Data.Token("Tickets")
            Hub.Net.Fire("QuestService.RE.Buy", item.name)
            bought += 1
            task.wait(Hub.Config.ItemDelay)
            if Hub.Data.Token("Tickets") >= before then break end
        end
    end
    return bought
end

function Hub.Items.Step()
    if Hub.Options.AutoPotion then Hub.Items.UsePotions() end
    if Hub.Options.AutoSpin then Hub.Items.UseSpins() end
    if Hub.Options.AutoGamepass then Hub.Items.UseGamepasses() end
    if Hub.Options.AutoTicketShop then Hub.Items.BuyTicketShop() end
end

Hub.Watch = { Seen = nil, Best = nil, Pulls = 0, StartAt = osClock(), StartGems = nil }

function Hub.Watch.Describe(unit)
    return string.format("%s [%s]%s", unit.Name, unit.Rarity or "?", unit.Mutation and (" · " .. unit.Mutation) or "")
end

function Hub.Watch.Alert(unit)
    local text = Hub.Watch.Describe(unit)
    pcall(function() Hub.UI.Toast("Rare pull", text, 8) end)
    local url = Hub.Options.WebhookUrl
    if type(url) ~= "string" or not url:find("^https://") or not Util.Request then return end
    local body = HttpService:JSONEncode({
        username = "Lazy Jiro Hub",
        embeds = { { title = "Anime Dice · rare pull", description = text, color = Hub.Config.WebhookColor } },
    })
    local ok, err = pcall(Util.Request, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    if not ok then warn("[AnimeDice] webhook:", err) end
end

function Hub.Watch.OnNew(unit)
    local watch = Hub.Watch
    watch.Pulls += 1
    if not watch.Best or unit.Potential > watch.Best.Potential then watch.Best = unit end
    if not Hub.Options.RareNotify then return end
    local rarities = Util.SetFromList(Hub.Options.NotifyRarities)
    local mutations = Util.SetFromList(Hub.Options.NotifyMutations)
    if rarities[unit.Rarity] or (unit.Mutation and mutations[unit.Mutation]) then watch.Alert(unit) end
end

function Hub.Watch.Step()
    local watch = Hub.Watch
    local units = Hub.Data.Units()
    if not watch.Seen then
        watch.Seen, watch.StartGems = {}, Hub.Data.Token("Gems")
        for _, unit in ipairs(units) do watch.Seen[unit.Key] = true end
        return
    end
    for _, unit in ipairs(units) do
        if not watch.Seen[unit.Key] then
            watch.Seen[unit.Key] = true
            watch.OnNew(unit)
        end
    end
end

---@return string[]  lines for the stats panel
function Hub.Watch.Stats()
    local watch = Hub.Watch
    local hours = math.max(osClock() - watch.StartAt, 1) / 3600
    return {
        string.format("Money %s/h · Rolls %s/h", Util.FormatNumber(Hub.Economy.Earned / hours), Util.FormatNumber(Hub.Roll.Session / hours)),
        string.format("Pulls %d · Gems %+d · Tower runs %d", watch.Pulls, Hub.Data.Token("Gems") - (watch.StartGems or 0), Hub.Tower.Runs),
        "Best pull: " .. (watch.Best and Hub.Watch.Describe(watch.Best) or "-"),
    }
end

Hub.Lock = { Status = "Off" }

---@return number  units locked this pass
function Hub.Lock.Step()
    if not Hub.Options.AutoLock then return 0 end
    local rank = GameLib.RarityOrder(Hub.Options.LockRarity)
    local mutations = Util.SetFromList(Hub.Options.LockMutations)
    local keys, count = {}, 0
    for _, unit in ipairs(Hub.Data.Units()) do
        if unit.Locked then continue end
        if (rank > 0 and GameLib.RarityOrder(unit.Rarity) >= rank) or (unit.Mutation and mutations[unit.Mutation]) then
            keys[unit.Key] = true
            count += 1
        end
    end
    if count > 0 then
        Hub.Net.Fire("UnitService.RE.SetLocked", keys)
        Hub.Data.Invalidate()
    end
    Hub.Lock.Status = count > 0 and (count .. " locked") or "Nothing new to lock"
    return count
end

Hub.Rejoin = { Hooked = false, Busy = false }

function Hub.Rejoin.Now()
    if Hub.Rejoin.Busy then return end
    Hub.Rejoin.Busy = true
    if Util.QueueTeleport then
        local resume = Hub.Options.Kaitun and "getgenv().AnimeDiceResume = true " or ""
        pcall(Util.QueueTeleport, resume .. Hub.Config.ReloadSource)
    end
    local ok, err = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
    if not ok then warn("[AnimeDice] rejoin:", err) end
    task.delay(Hub.Config.RejoinRetry, function() Hub.Rejoin.Busy = false end)
end

function Hub.Rejoin.Start()
    Hub.Options.AutoRejoin = true
    if Hub.Rejoin.Hooked then return end
    Hub.Rejoin.Hooked = true
    Hub:Connect(GuiService.ErrorMessageChanged, function(message)
        if Hub.Options.AutoRejoin and message ~= "" then task.delay(Hub.Config.RejoinDelay, Hub.Rejoin.Now) end
    end)
end

function Hub.Rejoin.Stop()
    Hub.Options.AutoRejoin = false
end

Hub.Rewards = { Status = "Off", DailyRetryAt = 0, Member = nil }

function Hub.Rewards.RedeemAll()
    local redeemed = Hub.Data.Table("RedeemedCodes")
    local sent = 0
    for code in pairs(GameLib.Codes or {}) do
        if type(code) == "string" and not redeemed[code] then
            Hub.Net.Fire("CodesService.RE.RedeemCode", code)
            sent += 1
            task.wait(Hub.Config.RedeemDelay)
        end
    end
    return sent > 0 and (sent .. " codes redeemed") or "All codes already redeemed"
end

---@return number  quests claimed
function Hub.Rewards.ClaimQuests()
    local periods = GameLib.Quests and GameLib.Quests.Periods
    local records = Hub.Data.Table("Quests")
    if type(periods) ~= "table" then return 0 end
    local claimedCount = 0
    for period, def in pairs(periods) do
        local record = records[period]
        if type(record) ~= "table" or type(def) ~= "table" then continue end
        local progress = type(record.progress) == "table" and record.progress or {}
        local claimed = type(record.claimed) == "table" and record.claimed or {}
        for _, quest in ipairs(def.quests or {}) do
            if not claimed[quest.id] and (tonumber(progress[quest.id]) or 0) >= (tonumber(quest.target) or math.huge) then
                Hub.Net.Fire("QuestService.RE.Claim", period, quest.id, record.expiresAt)
                claimedCount += 1
                task.wait(Hub.Config.ClaimDelay)
            end
        end
    end
    return claimedCount
end

function Hub.Rewards.ClaimOffline()
    if (tonumber(Hub.Data.Read("PendingOfflineEarnings")) or 0) > 0 then
        Hub.Net.Fire("OfflineEarningsService.RE.Claim")
    end
end

function Hub.Rewards.DailyReady()
    local cooldown = GameLib.Daily and tonumber(GameLib.Daily.Cooldown) or 82800
    local last = tonumber(Hub.Data.Read("LastDailyRewardClaim")) or 0
    return os.time() - last >= cooldown and osClock() >= Hub.Rewards.DailyRetryAt
end

function Hub.Rewards.InGroup()
    if Hub.Rewards.Member == nil then
        local groupId = GameLib.Group and tonumber(GameLib.Group.GroupId) or Hub.Config.GroupId
        local ok, member = pcall(LocalPlayer.IsInGroup, LocalPlayer, groupId)
        Hub.Rewards.Member = ok and member == true
    end
    return Hub.Rewards.Member
end

function Hub.Rewards.Step()
    if Hub.Options.AutoDaily and Hub.Rewards.DailyReady() then
        Hub.Rewards.DailyRetryAt = osClock() + 60
        Hub.Net.Fire("DailyRewardService.RE.Claim")
    end
    if Hub.Options.AutoGroup and not Hub.Data.Read("ClaimedGroupReward") and Hub.Rewards.InGroup() then
        Hub.Net.Fire("GroupRewardService.RE.Claim")
    end
    if Hub.Options.AutoOffline then Hub.Rewards.ClaimOffline() end
    if Hub.Options.AutoQuest then Hub.Rewards.ClaimQuests() end
end

Hub.Kaitun = { Status = "Off", Members = {
    "AntiAfk", "AutoRejoin", "RareNotify", "AutoLock", "TowerSmart", "AutoFuse", "DisableCutscene", "AutoRoll", "AutoCollect", "EquipBestUnitsAuto", "AutoLevelUp",
    "AutoBuyDice", "AutoEquipBestDice", "AutoBuyUpgrades", "AutoSell", "AutoRebirth", "AutoRebirthStats", "AutoGrade",
    "AutoTrait", "AutoTower", "AutoPotion", "AutoSpin", "AutoGamepass", "AutoTicketShop", "AutoDaily", "AutoGroup",
    "AutoOffline", "AutoQuest", "AutoGear", "AutoClearStorage",
} }

---@param fromTop boolean  take the rarest end instead of the commonest
---@return string[]        up to count names from a list sorted commonest first
function Hub.Kaitun.Slice(list, count, fromTop)
    local picked = {}
    local first = fromTop and math.max(#list - count + 1, 1) or 1
    for index = first, math.min(first + count - 1, #list) do
        table.insert(picked, list[index])
    end
    return picked
end

function Hub.Kaitun.SetMembers(on)
    local widgets = Hub.UI.Widgets
    for _, idx in ipairs(Hub.Kaitun.Members) do
        if Hub.UI.Blocked[idx] then
            Hub.Options[idx] = false
        elseif widgets[idx] then
            widgets[idx]:Set(on)
        else
            Hub.Options[idx] = on
        end
    end
end

function Hub.Kaitun.Start()
    Hub.Options.Kaitun = true
    local widgets = Hub.UI.Widgets
    local function Default(idx, value)
        if next(Util.SetFromList(Hub.Options[idx])) ~= nil then return end
        if widgets[idx] then widgets[idx]:Set(value) end
        Hub.Options[idx] = value
    end
    local slice = Hub.Kaitun.Slice
    local lists = Hub.UI.Lists
    local rarities, mutations = lists.Rarities, lists.Mutations
    if table.find(GameLib.ShopNames(), "Gems") then Default("TicketShopItems", { "Gems" }) end
    Default("SellRarities", slice(rarities, 2))
    Default("LockMutations", slice(mutations, 3, true))
    Default("NotifyRarities", slice(rarities, 4, true))
    Default("NotifyMutations", slice(mutations, 2, true))
    if widgets.LevelTarget then widgets.LevelTarget:Set(200) end
    Hub.Options.LevelTarget = 200
    Hub.Kaitun.SetMembers(true)
    task.defer(function() Hub.Rewards.RedeemAll() end)
end

function Hub.Kaitun.Stop()
    Hub.Options.Kaitun = false
    Hub.Kaitun.SetMembers(false)
end

function Hub.Kaitun.GetStatus()
    return string.format("R%d · %s", Hub.Data.Rebirth(), Hub.Economy.GetStatus())
end

Hub.UI = { Labels = {}, Lists = { Rarities = {}, Mutations = {} }, Widgets = {}, Tracked = {}, Blocked = {} }
local Library, Window

Hub.Profile = {}

function Hub.Profile.Path(name)
    return Hub.Config.SaveFolder .. "/" .. name
end

---@return boolean  true when the executor can read and write files
function Hub.Profile.Ready()
    if not (writefile and readfile and isfile) then return false end
    if makefolder then
        pcall(function()
            if not (isfolder and isfolder(Hub.Config.SaveFolder)) then makefolder(Hub.Config.SaveFolder) end
        end)
    end
    return true
end

---@return boolean, string?  saved, and why not
function Hub.Profile.Save()
    if not Hub.Profile.Ready() then return false, "This executor can't write files" end
    local values = {}
    for idx, entry in pairs(Hub.UI.Tracked) do
        local ok, value = pcall(entry.Get)
        if ok and value ~= nil then values[idx] = value end
    end
    local encoded, payload = pcall(HttpService.JSONEncode, HttpService, { Values = values })
    if not encoded then return false, "Could not encode the config" end
    local wrote, err = pcall(writefile, Hub.Profile.Path(Hub.Config.ConfigFile), payload)
    if not wrote then return false, tostring(err) end
    return true
end

---@return boolean, string?  loaded, and why not
function Hub.Profile.Load()
    if not Hub.Profile.Ready() then return false, "This executor can't read files" end
    local path = Hub.Profile.Path(Hub.Config.ConfigFile)
    local exists, found = pcall(isfile, path)
    if not (exists and found) then return false, "No saved config yet" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" or type(data.Values) ~= "table" then return false, "Saved config is damaged" end

    local kaitun
    for idx, value in pairs(data.Values) do
        local entry = Hub.UI.Tracked[idx]
        if entry then
            if idx == "Kaitun" then
                kaitun = { entry, value }
            else
                pcall(entry.Set, value)
            end
        end
    end
    if kaitun then pcall(kaitun[1].Set, kaitun[2]) end
    return true
end

function Hub.Profile.AutoloadEnabled()
    if not (isfile and readfile) then return false end
    local path = Hub.Profile.Path(Hub.Config.AutoloadFile)
    local ok, found = pcall(isfile, path)
    if not (ok and found) then return false end
    local read, text = pcall(readfile, path)
    return read and text == "1"
end

function Hub.Profile.SetAutoload(on)
    if not Hub.Profile.Ready() then return false end
    return (pcall(writefile, Hub.Profile.Path(Hub.Config.AutoloadFile), on and "1" or "0"))
end

function Hub.UI.Toast(title, text, duration)
    if not Window then return end
    pcall(Window.Notify, Window, { Title = title, Content = tostring(text), Duration = duration or 4 })
end

function Hub.UI.Notify(title, text)
    Hub.UI.Toast(title, text, 4)
end

---@param interval number  seconds between runs
function Hub.UI.Every(interval, fn)
    local elapsed = 0
    Hub:Connect(RunService.Heartbeat, function(dt)
        elapsed += dt
        if elapsed < interval then return end
        elapsed = 0
        local ok, err = pcall(fn)
        if not ok then warn("[AnimeDice] ui: " .. tostring(err)) end
    end)
end

---@param module table  feature with Start/Stop
function Hub.UI.StartStop(module)
    return function(on)
        if on then module.Start() else module.Stop() end
    end
end

---@return table  list from a game-data source, empty when it errors
function Hub.UI.Values(source, ...)
    local ok, list = pcall(source, ...)
    return ok and type(list) == "table" and list or {}
end

---@param fallback number  index used when the game renamed or removed the preferred value
function Hub.UI.Prefer(values, preferred, fallback)
    if table.find(values, preferred) then return preferred end
    return values[math.clamp(fallback, 1, math.max(#values, 1))]
end

---@param getter function  current value for the saved config
---@param setter function  applies a saved value to the widget
function Hub.UI.Track(idx, getter, setter)
    Hub.UI.Tracked[idx] = { Get = getter, Set = setter }
end

---@param extra function?  runs after the option is updated
function Hub.UI.Toggle(card, idx, name, desc, extra)
    local widget
    widget = card:AddToggle({
        Name = name,
        Description = desc,
        Default = Hub.Options[idx] == true,
        Flag = idx,
        Callback = function(on)
            local reason = Hub.UI.Blocked[idx]
            if on and reason then
                widget:Set(false, true)
                Hub.Options[idx] = false
                Hub.UI.Toast(name, reason, 5)
                return
            end
            Hub.Options[idx] = on
            if on then Hub.Scheduler.Resume(idx) end
            if extra then extra(on) end
        end,
    })
    Hub.UI.Widgets[idx] = widget
    Hub.Options[idx] = widget.Value
    Hub.UI.Track(idx, function() return widget.Value end, function(value) widget:Set(value == true) end)
    return widget
end

function Hub.UI.Slider(card, idx, name, min, max, increment, suffix)
    local widget = card:AddSlider({
        Name = name,
        Min = min,
        Max = max,
        Increment = increment,
        Suffix = suffix,
        Default = Hub.Options[idx],
        Flag = idx,
        Callback = function(value) Hub.Options[idx] = value end,
    })
    Hub.UI.Widgets[idx] = widget
    Hub.Options[idx] = widget.Value
    Hub.UI.Track(idx, function() return widget.Value end, function(value)
        widget:Set(tonumber(value) or widget.Value)
    end)
    return widget
end

---@param default string?  value shown first, falls back to the first option
---@param extra function?  runs after the option is updated
function Hub.UI.Dropdown(card, idx, name, desc, values, default, extra)
    local widget = card:AddDropdown({
        Name = name,
        Description = desc,
        Options = values,
        Stacked = true,
        Default = default,
        Flag = idx,
        Callback = function(value)
            Hub.Options[idx] = value
            if extra then extra(value) end
        end,
    })
    Hub.UI.Widgets[idx] = widget
    if widget.Value ~= nil then Hub.Options[idx] = widget.Value end
    Hub.UI.Track(idx, function() return widget.Value end, function(value)
        if table.find(values, value) then widget:Set(value) end
    end)
    return widget
end

function Hub.UI.MultiDropdown(card, idx, name, desc, values)
    local widget = card:AddDropdown({
        Name = name,
        Description = desc,
        Options = values,
        Multi = true,
        Stacked = true,
        Default = {},
        Flag = idx,
        Callback = function(set) Hub.Options[idx] = set end,
    })
    Hub.UI.Widgets[idx] = widget
    Hub.Options[idx] = widget.Value
    Hub.UI.Track(idx, function() return Util.SortedKeys(widget.Value) end, function(list) widget:Set(list) end)
    return widget
end

function Hub.UI.Input(card, idx, name, desc, placeholder)
    local widget = card:AddInput({
        Name = name,
        Description = desc,
        Placeholder = placeholder,
        Default = "",
        Stacked = true,
        Flag = idx,
        Callback = function(text) Hub.Options[idx] = text end,
    })
    Hub.UI.Widgets[idx] = widget
    Hub.UI.Track(idx, function() return widget.Get() end, function(value)
        widget:Set(tostring(value))
        Hub.Options[idx] = tostring(value)
    end)
    return widget
end

---@param default Enum.KeyCode  never Unknown, the UI would fire it on every mouse click
function Hub.UI.Keybind(card, idx, name, default, onPress)
    local widget = card:AddKeybind({ Name = name, Default = default, Callback = onPress })
    Hub.UI.Track(idx, function() return widget.Value.Name end, function(keyName)
        local ok, key = pcall(function() return Enum.KeyCode[keyName] end)
        if ok and key then widget:Set(key, true) end
    end)
    return widget
end

Hub.UI.Needs = {
    Kaitun = { "DataClient", "Entry" },
    AutoCollect = { "DataClient" },
    EquipBestUnitsAuto = { "DataClient", "Entry" },
    AutoLevelUp = { "DataClient", "Entry", "UnitUtil" },
    AutoTower = { "Towers" },
    AutoSell = { "DataClient", "Entry" },
    AutoClearStorage = { "DataClient", "Entry", "Buffs" },
    AutoBuyDice = { "DataClient", "Dice" },
    AutoEquipBestDice = { "DataClient", "Dice" },
    AutoBuyUpgrades = { "DataClient", "Upgrades", "Tree", "Buffs", "BuffsConfig" },
    AutoRebirth = { "DataClient", "Rebirths" },
    AutoRebirthStats = { "DataClient", "RebirthStats" },
    AutoGamepass = { "DataClient", "Entry" },
    AutoGrade = { "DataClient", "Entry", "Grades" },
    AutoTrait = { "DataClient", "Entry", "Traits" },
    AutoFuse = { "DataClient", "Entry", "FusingConfig" },
    AutoGear = { "DataClient", "Entry" },
    AutoLock = { "DataClient", "Entry" },
    AutoPotion = { "DataClient", "Entry" },
    AutoSpin = { "DataClient", "Entry" },
    AutoTicketShop = { "DataClient", "Quests" },
    AutoQuest = { "DataClient", "Quests" },
    AutoDaily = { "DataClient" },
    AutoGroup = { "DataClient" },
    AutoOffline = { "DataClient" },
    RareNotify = { "DataClient", "Entry" },
}

Hub.UI.Remotes = {
    AutoRoll = { "RollService.RF.RollDice" },
    AutoCollect = { "PlotService.RE.CollectBalance" },
    EquipBestUnitsAuto = { "PlotService.RE.EquipBest", "PlotService.RE.InteractSlot", "UnitService.RF.Equip" },
    AutoLevelUp = { "PlotService.RE.LevelUpSlot" },
    AutoTower = { "Towers.RF.PlayTower", "Towers.RF.CompleteTowerFloor", "Towers.RF.CancelTower" },
    AutoSell = { "SellService.RF.SellInventory" },
    AutoClearStorage = { "SellService.RF.SellInventory" },
    AutoBuyDice = { "DiceShopService.RE.BuyDice" },
    AutoEquipBestDice = { "DiceShopService.RE.EquipDice" },
    AutoBuyUpgrades = { "RE.BuyUpgrade" },
    AutoRebirth = { "RebirthService.RE.Rebirth" },
    AutoRebirthStats = { "RebirthService.RE.AddStat" },
    AutoGamepass = { "GamepassService.RE.Use" },
    AutoGrade = { "GradeService.RE.Roll" },
    AutoTrait = { "TraitService.RE.Roll" },
    AutoFuse = { "FusingService.RE.Fuse" },
    AutoGear = { "GearService.RE.Equip" },
    AutoLock = { "UnitService.RE.SetLocked" },
    AutoPotion = { "BoostService.RE.Use" },
    AutoSpin = { "SpinService.RE.Use" },
    AutoTicketShop = { "QuestService.RE.Buy" },
    AutoQuest = { "QuestService.RE.Claim" },
    AutoDaily = { "DailyRewardService.RE.Claim" },
    AutoGroup = { "GroupRewardService.RE.Claim" },
    AutoOffline = { "OfflineEarningsService.RE.Claim" },
}

---@return string?, boolean  first missing module or remote, true when it is a remote
function Hub.UI.MissingFor(idx)
    for _, key in ipairs(Hub.UI.Needs[idx] or {}) do
        if GameLib[key] == nil then return key, false end
    end
    for _, path in ipairs(Hub.UI.Remotes[idx] or {}) do
        if not Hub.Net.Get(path) then return path, true end
    end
    return nil, false
end

function Hub.UI.Gate()
    local blocked = 0
    local seen = {}
    for idx in pairs(Hub.UI.Needs) do seen[idx] = true end
    for idx in pairs(Hub.UI.Remotes) do seen[idx] = true end

    for idx in pairs(seen) do
        local missing, isRemote = Hub.UI.MissingFor(idx)
        local widget = Hub.UI.Widgets[idx]
        if widget and missing then
            blocked += 1
            warn("[AnimeDice] " .. idx .. " blocked, missing " .. (isRemote and "remote " or "module ") .. missing)
            Hub.UI.Blocked[idx] = isRemote and "The game changed, waiting for a script update"
                or "Not available on this executor"
            widget:Set(false, true)
            Hub.Options[idx] = false
        end
    end
    if blocked == 0 then return end
    Hub.UI.Toast("Lazy Jiro Hub", blocked .. " features are turned off for now", 8)
end

function Hub.UI.DrainHalted()
    local halted = Hub.State.Halted
    while #halted > 0 do
        local entry = table.remove(halted, 1)
        local stopKaitun = false
        for _, idx in ipairs(entry[2]) do
            local widget = Hub.UI.Widgets[idx]
            if widget and widget.Value == true then widget:Set(false) end
            stopKaitun = stopKaitun or table.find(Hub.Kaitun.Members, idx) ~= nil
        end

        local kaitun = Hub.UI.Widgets.Kaitun
        if stopKaitun and kaitun and kaitun.Value == true then kaitun:Set(false) end
        Hub.UI.Toast("Lazy Jiro Hub", entry[1] .. " stopped: " .. tostring(entry[3]), 8)
    end
end

function Hub.UI.DrainNotices()
    local notices = Hub.State.Notices
    while #notices > 0 do
        local notice = table.remove(notices, 1)
        Hub.UI.Toast(notice[1], notice[2], 8)
    end
end

function Hub.UI.BuildMain(page)
    local tab = page:AddTab("Home")
    local labels = Hub.UI.Labels

    local status = tab:AddCard("Status", "Left")
    labels.Economy = status:AddLabel("Economy: -")
    labels.Roll = status:AddLabel("Rolling: -")
    labels.Units = status:AddLabel("Units: -")
    labels.Tower = status:AddLabel("Tower: -")

    local stats = tab:AddCard("Session Stats", "Left")
    labels.Stats = stats:AddLabel("-")

    local discord = tab:AddCard("Discord", "Right")
    discord:AddLabel(Hub.Config.Discord)
    discord:AddButton({ Name = "Copy Discord Link", Callback = function()
        if Util.Copy(Hub.Config.Discord) then
            Hub.UI.Notify("Discord", "Link copied")
        else
            Hub.UI.Notify("Discord", Hub.Config.Discord)
        end
    end })

    local master = tab:AddCard("Kaitun", "Right")
    Hub.UI.Toggle(master, "Kaitun", "Kaitun (full auto)", "Rolls, levels, climbs and rebirths itself", Hub.UI.StartStop(Hub.Kaitun))
    labels.Kaitun = master:AddLabel("-")
end

function Hub.UI.BuildFarm(page)
    local tab = page:AddTab("Auto Farm")
    local rarities = Hub.UI.Values(GameLib.UnitRarities)

    local roll = tab:AddCard("Rolling", "Left")
    Hub.UI.Toggle(roll, "AutoRoll", "Fast roll", "Rolls non-stop, no roll animation")
    Hub.UI.Slider(roll, "RollInterval", "Roll interval", 0.02, 0.5, 0.01, "s")
    roll:AddButton({ Name = "Roll Once", Callback = function() Hub.Roll.Once() end })
    roll:AddButton({ Name = "Reset roll counter", Callback = Hub.Roll.ResetCounter })

    local plot = tab:AddCard("Placement", "Left")
    Hub.UI.Toggle(plot, "EquipBestUnitsAuto", "Auto equip best")
    Hub.UI.Dropdown(plot, "PlacementMode", "Pick units by", "Potential places your strongest units even at level 1",
        { "Potential", "Current income" }, "Potential")
    Hub.UI.Slider(plot, "EquipInterval", "Equip interval", 1, 120, 1, "s")
    plot:AddButton({ Name = "Equip Best Now", Callback = Hub.Plot.EquipBest })

    local collect = tab:AddCard("Collect", "Right")
    Hub.UI.Toggle(collect, "AutoCollect", "Auto collect")
    Hub.UI.Slider(collect, "CollectInterval", "Collect interval", 0.5, 60, 0.5, "s")
    collect:AddButton({ Name = "Collect Now", Callback = Hub.Plot.CollectNow })

    local level = tab:AddCard("Level Up", "Right")
    Hub.UI.Toggle(level, "AutoLevelUp", "Auto level up", "Levels plotted units when affordable")
    Hub.UI.Dropdown(level, "LevelMinRarity", "Minimum rarity (plotted units)", nil, rarities, Hub.UI.Prefer(rarities, "Common", 1))
    Hub.UI.Slider(level, "LevelTarget", "Target level", 2, 200, 1)
    Hub.UI.Slider(level, "LevelPayback", "Max payback time", 10, 3600, 10, "s")
    level:AddButton({ Name = "Run a pass", Callback = function()
        Hub.UI.Notify("Level Up", Hub.Plot.LevelPass(true) .. " levelled")
    end })
end

function Hub.UI.BuildEconomy(page)
    local tab = page:AddTab("Economy")
    local rarities = Hub.UI.Values(GameLib.UnitRarities)

    local dice = tab:AddCard("Dice", "Left")
    Hub.UI.Toggle(dice, "AutoBuyDice", "Auto buy dice", "Buys the luckiest dice you can afford")
    Hub.UI.Toggle(dice, "AutoEquipBestDice", "Equip best owned dice")
    dice:AddButton({ Name = "Equip Best Now", Callback = Hub.Dice.EquipBest })

    local upgrade = tab:AddCard("Upgrades", "Right")
    Hub.UI.Toggle(upgrade, "AutoBuyUpgrades", "Auto upgrades")
    Hub.UI.MultiDropdown(upgrade, "UpgradeFilter", "Branches to upgrade", "Empty buys every branch", Hub.UI.Values(Hub.Upgrade.Branches))
    Hub.UI.Slider(upgrade, "UpgradePayback", "Income payback", 30, 7200, 30, "s")
    upgrade:AddButton({ Name = "Buy available upgrades", Callback = function()
        Hub.UI.Notify("Upgrades", Hub.Upgrade.BuyAll() .. " bought")
    end })

    local sell = tab:AddCard("Sell", "Left")
    Hub.UI.Toggle(sell, "AutoSell", "Auto sell", "Never sells plot or tower team units")
    Hub.UI.MultiDropdown(sell, "SellRarities", "Rarities to sell", nil, rarities)
    Hub.UI.MultiDropdown(sell, "SellKeepMutations", "Mutations to keep", nil, Hub.UI.Values(GameLib.MutationNames))
    Hub.UI.Slider(sell, "KeepPerRarity", "Keep per rarity", 0, 20, 1)
    Hub.UI.Slider(sell, "SellInterval", "Interval", 0.5, 60, 0.5, "s")
    sell:AddButton({ Name = "Sell Now", Callback = function()
        Hub.UI.Notify("Sell", Hub.Sell.SellNow())
    end })

    local storage = tab:AddCard("Full Storage", "Right")
    Hub.UI.Toggle(storage, "AutoClearStorage", "Auto clear storage", "Sells weakest spares so rolling never stops")
    Hub.UI.Dropdown(storage, "ClearKeepRarity", "Never clear rarity and above", nil, rarities,
        Hub.UI.Prefer(rarities, "Mythical", math.ceil(#rarities / 2)))

    local rebirth = tab:AddCard("Rebirth", "Right")
    Hub.UI.Toggle(rebirth, "AutoRebirth", "Auto rebirth", "Rebirths as soon as you can afford it")
    rebirth:AddButton({ Name = "Rebirth Now", Primary = true, Callback = function()
        Hub.Rebirth.RebirthNow()
        Hub.UI.Notify("Rebirth", Hub.Rebirth.Status)
    end })

    local statNames = Hub.UI.Values(GameLib.RebirthStatNames)
    local stats = tab:AddCard("Rebirth Stats", "Left")
    Hub.UI.Toggle(stats, "AutoRebirthStats", "Auto spend points", "New rebirth points go into the stat below")
    Hub.UI.Dropdown(stats, "RebirthStat", "Stat", nil, statNames, Hub.UI.Prefer(statNames, "Money", 1))
    stats:AddButton({ Name = "Spend Points Now", Callback = function()
        Hub.UI.Notify("Rebirth Stats", Hub.Rebirth.SpendPoints() .. " points spent")
    end })
    stats:AddButton({ Name = "Reset Stats", Callback = function()
        local ok, why = Hub.Rebirth.ResetStats()
        Hub.UI.Notify("Rebirth Stats", ok and "Reset Token used" or why)
    end })
end

function Hub.UI.BuildUnits(page)
    local tab = page:AddTab("Units")
    local rarities = Hub.UI.Values(GameLib.UnitRarities)
    local mutations = Hub.UI.Values(GameLib.MutationNames)
    local grades, traits = Hub.UI.Values(GameLib.GradeNames), Hub.UI.Values(GameLib.TraitNames)

    local grade = tab:AddCard("Grades", "Left")
    Hub.UI.Toggle(grade, "AutoGrade", "Auto grade", "Rerolls plot and tower units to the minimum")
    Hub.UI.Dropdown(grade, "GradeTarget", "Minimum grade", nil, grades, Hub.UI.Prefer(grades, "S", math.ceil(#grades / 2)))
    Hub.UI.Toggle(grade, "GradeOverwrite", "Overwrite tiers (S+)")
    grade:AddButton({ Name = "Grade Once", Callback = Hub.Grade.RollOne })

    local trait = tab:AddCard("Traits", "Left")
    Hub.UI.Toggle(trait, "AutoTrait", "Auto trait", "Rerolls plot and tower units to the minimum")
    Hub.UI.Dropdown(trait, "TraitTarget", "Minimum trait", nil, traits, Hub.UI.Prefer(traits, "Samurai", math.ceil(#traits / 2)))
    Hub.UI.Toggle(trait, "TraitOverwrite", "Overwrite top traits")
    trait:AddButton({ Name = "Trait Once", Callback = Hub.Trait.RollOne })

    local lock = tab:AddCard("Auto Lock", "Right")
    Hub.UI.Toggle(lock, "AutoLock", "Auto lock rare units", "Locked units are never sold or fused")
    Hub.UI.Dropdown(lock, "LockRarity", "Lock rarity and above", nil, rarities, Hub.UI.Prefer(rarities, "Secret I", #rarities - 3))
    Hub.UI.MultiDropdown(lock, "LockMutations", "Lock mutations", nil, mutations)

    local gear = tab:AddCard("Gear", "Right")
    Hub.UI.Toggle(gear, "AutoGear", "Auto equip best gear", "Wears your rarest gear in every slot")
    gear:AddButton({ Name = "Equip Best Now", Callback = function()
        Hub.UI.Notify("Gear", Hub.Gear.EquipBest() .. " slots upgraded")
    end })

    local fuse = tab:AddCard("Fusing", "Right")
    Hub.UI.Toggle(fuse, "AutoFuse", "Auto Fuse", "Fuses spare trios only when worth it")
    Hub.UI.MultiDropdown(fuse, "FuseRarities", "Rarities to fuse", "Empty uses any spare below the never-clear rarity", rarities)
    fuse:AddButton({ Name = "Fuse Now", Callback = Hub.Fuse.FuseNow })
end

function Hub.UI.BuildTower(page)
    local tab = page:AddTab("Tower")

    local group = tab:AddCard("Auto Tower", "Left")
    Hub.UI.Toggle(group, "AutoTower", "Auto tower", "Climbs, restarts after each run")
    local labels = Hub.UI.Values(Hub.Tower.Labels)
    Hub.UI.Dropdown(group, "TowerDifficulty", "Difficulty", nil, labels, labels[1], function(label)
        Hub.Options.TowerName = Hub.Tower.NameFromLabel(label)
    end)
    Hub.UI.Toggle(group, "TowerSmart", "Auto Difficulty", "Up after a full clear, down on an early loss")
    if labels[1] then Hub.Options.TowerName = Hub.Tower.NameFromLabel(labels[1]) end

    local run = tab:AddCard("Run Settings", "Right")
    Hub.UI.Slider(run, "TowerStopFloor", "Stop at floor", 1, 500, 1)
    Hub.UI.Toggle(run, "TowerReequip", "Re-equip each run")
    run:AddButton({ Name = "Equip best team", Callback = Hub.Tower.EquipTeam })
end

function Hub.UI.BuildItems(page)
    local tab = page:AddTab("Items")

    local potion = tab:AddCard("Potions", "Left")
    Hub.UI.Toggle(potion, "AutoPotion", "Auto potion", "Uses each boost only when useful")
    Hub.UI.MultiDropdown(potion, "PotionFilter", "Potions to use", "Empty uses every potion", Hub.UI.Values(GameLib.NamesOfKind, "Boost"))
    potion:AddButton({ Name = "Use Now", Callback = function()
        Hub.UI.Notify("Potions", Hub.Items.UsePotions(true) .. " used")
    end })

    local spin = tab:AddCard("Spins", "Right")
    Hub.UI.Toggle(spin, "AutoSpin", "Auto use spins", "Uses Lucky and Jackpot spins")
    spin:AddButton({ Name = "Use Spins Now", Callback = function()
        Hub.UI.Notify("Spins", Hub.Items.UseSpins() .. " used")
    end })
    Hub.UI.Toggle(spin, "AutoGamepass", "Auto gamepass items", "Unlocks gamepasses from codes and rewards")

    local shop = tab:AddCard("Ticket Shop", "Right")
    Hub.UI.Toggle(shop, "AutoTicketShop", "Auto buy with tickets", "Spends quest tickets on your picks")
    Hub.UI.MultiDropdown(shop, "TicketShopItems", "Items to buy", nil, Hub.UI.Values(GameLib.ShopNames))
    shop:AddButton({ Name = "Buy Now", Callback = function()
        Hub.UI.Notify("Ticket Shop", Hub.Items.BuyTicketShop() .. " bought")
    end })
end

function Hub.UI.BuildRewards(page)
    local tab = page:AddTab("Rewards")

    local codes = tab:AddCard("Codes", "Left")
    codes:AddButton({ Name = "Redeem All Codes", Primary = true, Callback = function()
        Hub.UI.Notify("Codes", Hub.Rewards.RedeemAll())
    end })

    local quest = tab:AddCard("Quests", "Left")
    Hub.UI.Toggle(quest, "AutoQuest", "Auto claim quests")
    quest:AddButton({ Name = "Claim now", Callback = function()
        Hub.UI.Notify("Quests", Hub.Rewards.ClaimQuests() .. " claimed")
    end })

    local claims = tab:AddCard("Claims", "Right")
    Hub.UI.Toggle(claims, "AutoDaily", "Auto daily reward")
    Hub.UI.Toggle(claims, "AutoGroup", "Auto group reward")
    Hub.UI.Toggle(claims, "AutoOffline", "Auto offline earnings")
end

function Hub.UI.BuildPlayer(page)
    local tab = page:AddTab("Player")

    local move = tab:AddCard("Movement", "Left")
    Hub.UI.Toggle(move, "WalkSpeed", "Walk speed", nil, function(on)
        if on then Hub.Move.SpeedStart() else Hub.Move.SpeedStop() end
    end)
    Hub.UI.Slider(move, "WalkSpeedValue", "Speed", 16, 200, 1)
    Hub.UI.Toggle(move, "InfiniteJump", "Infinite jump", nil, function(on)
        if on then Hub.Move.JumpStart() else Hub.Move.JumpStop() end
    end)

    local util = tab:AddCard("Utility", "Left")
    Hub.UI.Toggle(util, "AntiAfk", "Anti-AFK", nil, Hub.UI.StartStop(Hub.AntiAfk))
    Hub.UI.Toggle(util, "AutoRejoin", "Auto rejoin", "Rejoins after a disconnect, resumes Kaitun", Hub.UI.StartStop(Hub.Rejoin))
    Hub.UI.Toggle(util, "DisableCutscene", "Disable cutscenes", "Skips roll and fuse reveal cutscenes", function(on)
        if not on then Hub.Cutscene.Restore() end
    end)

    local air = tab:AddCard("Fly and No Clip", "Right")
    Hub.UI.Toggle(air, "NoClip", "No clip", nil, function(on)
        if on then Hub.Move.NoClipStart() else Hub.Move.NoClipStop() end
    end)
    Hub.UI.Keybind(air, "NoClipKey", "No clip key", Enum.KeyCode.N, function()
        local widget = Hub.UI.Widgets.NoClip
        widget:Set(not widget.Value)
    end)
    Hub.UI.Toggle(air, "Fly", "Fly", nil, function(on)
        if on then Hub.Move.FlyStart() else Hub.Move.FlyStop() end
    end)
    Hub.UI.Keybind(air, "FlyKey", "Fly key", Enum.KeyCode.G, function()
        local widget = Hub.UI.Widgets.Fly
        widget:Set(not widget.Value)
    end)
    Hub.UI.Slider(air, "FlySpeed", "Fly speed", 20, 300, 1)

    local alerts = tab:AddCard("Rare Alerts", "Right")
    Hub.UI.Toggle(alerts, "RareNotify", "Alert on rare pulls")
    Hub.UI.MultiDropdown(alerts, "NotifyRarities", "Rarities", nil, Hub.UI.Values(GameLib.UnitRarities))
    Hub.UI.MultiDropdown(alerts, "NotifyMutations", "Mutations", nil, Hub.UI.Values(GameLib.MutationNames))
    Hub.UI.Input(alerts, "WebhookUrl", "Discord webhook", nil, "Optional webhook URL")
    alerts:AddButton({ Name = "Send test alert", Callback = function()
        local rarities, mutations = Hub.UI.Lists.Rarities, Hub.UI.Lists.Mutations
        Hub.Watch.Alert({ Name = "Test", Rarity = rarities[#rarities] or "?", Mutation = mutations[#mutations] })
    end })
end

function Hub.UI.BuildSettings(page)
    local tab = page:AddTab("Settings")

    local menu = tab:AddCard("Menu", "Left")
    menu:AddKeybind({ Name = "Menu key", Default = Enum.KeyCode.LeftControl, Changed = function(key)
        Window:SetToggleKey(key)
    end })
    menu:AddToggle({ Name = "Falling petals", Default = true, Callback = function(on) Window:SetPetals(on) end })
    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    menu:AddSlider({ Name = "UI scale", Min = 50, Max = 120, Increment = 5, Suffix = "%", Default = mobile and 75 or 100,
        Callback = function(value) Window:SetScale(value / 100) end })
    menu:AddButton({ Name = "Unload Script", Callback = function() Window:Destroy() end })

    local profile = tab:AddCard("Config", "Right")
    profile:AddButton({ Name = "Save Config", Primary = true, Callback = function()
        local ok, why = Hub.Profile.Save()
        Hub.UI.Notify("Config", ok and "Config saved" or why)
    end })
    profile:AddButton({ Name = "Load Config", Callback = function()
        local ok, why = Hub.Profile.Load()
        Hub.UI.Notify("Config", ok and "Config loaded" or why)
    end })
    profile:AddToggle({ Name = "Auto load on start", Description = "Loads your saved config on execute",
        Default = Hub.Profile.AutoloadEnabled(), Callback = function(on) Hub.Profile.SetAutoload(on) end })
end

function Hub.UI.RefreshStatus()
    local labels = Hub.UI.Labels
    if not labels.Kaitun then return end

    labels.Economy:Set(string.format("Economy: $%s · R%d · Gems %s · Tickets %s",
        Util.FormatNumber(Hub.Data.Money()), Hub.Data.Rebirth(),
        Util.FormatNumber(Hub.Data.Token("Gems")), Util.FormatNumber(Hub.Data.Token("Tickets"))))
    labels.Roll:Set("Rolling: " .. Hub.Roll.GetStatus())
    labels.Units:Set(string.format("Units: Storage %s · Grade: %s · Trait: %s", Hub.Storage.Status, Hub.Grade.Status, Hub.Trait.Status))
    labels.Tower:Set("Tower: " .. Hub.Tower.GetStatus())
    labels.Kaitun:Set(Hub.Kaitun.GetStatus() .. "\nUpgrades: " .. Hub.Upgrade.Status .. "\nLevels: " .. Hub.Plot.Status)
    labels.Stats:Set(table.concat(Hub.Watch.Stats(), "\n"))
end

function Hub.UI.Build()
    Hub.UI.Lists = { Rarities = Hub.UI.Values(GameLib.UnitRarities), Mutations = Hub.UI.Values(GameLib.MutationNames) }
    local layout = {
        { "Main", "Home", Hub.UI.BuildMain },
        { "Farming", "Auto Farm", Hub.UI.BuildFarm },
        { nil, "Tower", Hub.UI.BuildTower },
        { "Progression", "Units", Hub.UI.BuildUnits },
        { nil, "Economy", Hub.UI.BuildEconomy },
        { nil, "Items", Hub.UI.BuildItems },
        { nil, "Rewards", Hub.UI.BuildRewards },
        { "Misc", "Player", Hub.UI.BuildPlayer },
        { nil, "Settings", Hub.UI.BuildSettings },
    }
    for _, section in ipairs(layout) do
        if section[1] then Window:AddCategory(section[1]) end
        local page = Window:AddPage({ Name = section[2] })
        Util.Try("ui " .. section[2], section[3], page)
    end

    Util.Try("ui gate", Hub.UI.Gate)
    Hub.UI.Every(Hub.Config.StatusInterval, Hub.UI.RefreshStatus)
    Hub.UI.Every(Hub.Config.StatusInterval, Hub.UI.DrainHalted)
    Hub.UI.Every(Hub.Config.StatusInterval, Hub.UI.DrainNotices)
end

local function BuildInterface()
    local lib, problem = Util.LoadLibrary(Hub.Config.UiSource)
    if not lib then
        Util.Alert(problem)
        return
    end
    Library = lib
    pcall(Banner.Step, "UI library")
    Hub.Library = Library

    local created, result = pcall(Library.CreateWindow, Library, {
        Name = "LAZY JIRO HUB",
        Subtitle = "Anime Dice",
        ToggleKey = Enum.KeyCode.LeftControl,
    })
    if not created or type(result) ~= "table" then
        Util.Alert("The menu failed to open: " .. tostring(result))
        return
    end
    Window = result
    Hub.UI.Window = Window

    -- every way of closing the menu (X button, Unload button, re-execute) funnels through Destroy
    local destroyWindow = Window.Destroy
    Window.Destroy = function(self)
        Hub:Unload()
        destroyWindow(self)
    end

    Util.Try("ui build", Hub.UI.Build)
    task.defer(Util.Try, "boot", Hub.Boot)
    task.defer(function()
        if Hub.State.Unloaded then return end
        if Hub.Profile.AutoloadEnabled() then
            Util.Try("autoload config", Hub.Profile.Load)
        end
        if environment.AnimeDiceResume then
            environment.AnimeDiceResume = nil
            local kaitun = Hub.UI.Widgets.Kaitun
            if kaitun then kaitun:Set(true) end
        end
    end)
    return true
end

function Hub.Boot()
    Hub:Connect(LocalPlayer.CharacterAdded, function(character)
        Hub.Player:Bind(character)
        task.defer(Hub.Move.Rebind)
    end)
    Hub.Roll.ResetCounter()

    local options, config = Hub.Options, Hub.Config
    local every = Hub.Scheduler.Every
    every("Roll", function() return options.RollInterval end, Hub.Roll.Step, { "AutoRoll" })
    every("Collect", function() return options.CollectInterval end, Hub.Plot.CollectStep, { "AutoCollect" })
    every("Equip", function() return options.EquipInterval end, Hub.Plot.EquipStep, { "EquipBestUnitsAuto" })
    every("Economy", 1, Hub.Economy.Step, { "AutoBuyDice", "AutoEquipBestDice", "AutoRebirth", "AutoRebirthStats", "AutoBuyUpgrades", "AutoLevelUp" })
    every("Sell", function() return options.SellInterval end, Hub.Sell.Step, { "AutoSell" })
    every("Storage", 1, Hub.Storage.Step, { "AutoClearStorage" })
    every("Grade", config.GradeDelay, Hub.Grade.Step, { "AutoGrade" })
    every("Trait", config.TraitDelay, Hub.Trait.Step, { "AutoTrait" })
    every("Fuse", config.FuseDelay, Hub.Fuse.Step, { "AutoFuse" })
    every("Tower", config.TowerTick, Hub.Tower.Step, { "AutoTower" })
    every("Items", config.RewardsInterval, Hub.Items.Step, { "AutoPotion", "AutoSpin", "AutoGamepass", "AutoTicketShop" })
    every("Gear", config.RewardsInterval, Hub.Gear.Step, { "AutoGear" })
    every("Watch", 1, Hub.Watch.Step, { "RareNotify" })
    every("Lock", config.RewardsInterval, Hub.Lock.Step, { "AutoLock" })
    every("Rewards", config.RewardsInterval, Hub.Rewards.Step, { "AutoDaily", "AutoGroup", "AutoOffline", "AutoQuest" })
    every("Speed", 1, Hub.Move.ApplyWalkSpeed, { "WalkSpeed" })
    every("Cutscene", 1, Hub.Cutscene.Step, { "DisableCutscene" })
    Hub.Scheduler.Boot()
end

function Hub:Unload()
    if self.State.Unloaded then return end
    self.State.Unloaded = true
    self.State.Alive = false
    if environment.AnimeDiceUnload == self.State.UnloadEntry then environment.AnimeDiceUnload = nil end
    self.Options.AutoTower = false
    if Hub.Tower.State ~= "Idle" then Hub.Tower.Leave() end
    Hub.Move.SpeedStop()
    Hub.Move.NoClipStop()
    Hub.Move.FlyStop()
    Hub.Cutscene.Restore()
    for _, connection in ipairs(self.State.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.State.Connections)
end

Hub.State.UnloadEntry = function()
    local window = Hub.UI.Window
    if window then pcall(window.Destroy, window) end
    Hub:Unload()
end
environment.AnimeDiceUnload = Hub.State.UnloadEntry

if LocalPlayer.Character then
    Hub.Player:Bind(LocalPlayer.Character)
end

pcall(Banner.Step, "Systems")
if BuildInterface() then
    pcall(Banner.Step, "Interface")
    pcall(Banner.Ready)
end

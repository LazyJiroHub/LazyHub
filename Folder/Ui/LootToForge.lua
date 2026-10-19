local Intro = (getgenv and getgenv().LazyJiroIntro) or { Set = function() end, Finish = function() end, Close = function() end }

Intro.Set("Loading menu", 0.15)
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jiroscriptsss/LazyHub/main/LazyJiroUI.lua"))()
Intro.Set("Building interface", 0.4)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetData
pcall(function() PetData = require(ReplicatedStorage.LocalData.PetData) end)

local DS = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Dungeon_Server")
local PetServer = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Pet_Server")
local DeleteRE = PetServer:WaitForChild("DeleteRE")
local TryHatchEggRE = PetServer:WaitForChild("TryHatchEggRE")
local TryOpenEggRE = PetServer:WaitForChild("TryOpenEggRE")
local LuckPetRF = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Season_Server"):WaitForChild("LuckPetRF")

local State = { Running = false, AutoSell = false, AutoRoll = false, AutoHatch = false, Rounds = 0, Status = "Idle", RunId = 0, GodMode = false, AutoKill = false }

local function updateStatus(status) State.Status = status end

local function farmLoop()
    State.RunId += 1
    local run = State.RunId
    local function active() return State.Running and State.RunId == run end

    local spawned = false
    while active() do
        updateStatus("Claiming Daily...")
        pcall(function() DS.TryClaimDailyDunTicRE:FireServer() end)
        task.wait(0.1)

        updateStatus("Entering Dungeon...")
        pcall(function() DS.TryIntoDungeonRF:InvokeServer(true, 50) end)
        task.wait(0.1)

        if not spawned then
            spawned = true
            for _ = 1, 5 do
                task.spawn(function()
                    while active() do
                        pcall(function()
                            DS.StartRoundRE:FireServer(50)
                            DS.CompleteRoundRF:InvokeServer(50)
                        end)
                        State.Rounds += 1
                        task.wait(0.05)
                    end
                end)
            end
        end

        updateStatus("Farming Rounds...")
        task.wait(1)
    end
    if State.RunId == run then updateStatus("Idle") end
end

local function autoRollLoop()
    while State.AutoRoll do
        pcall(function() LuckPetRF:InvokeServer() end)
        task.wait(0.5)
    end
end

local function autoHatchLoop()
    while State.AutoHatch do
        for i = 1, 8 do pcall(function() TryHatchEggRE:FireServer(i) end) end
        task.wait(0.1)
        for i = 1, 8 do pcall(function() TryOpenEggRE:FireServer(i) end) end
        task.wait(0.5)
    end
end

local function sellAllPets()
    local soldCount = 0
    if not PetData then return 0 end
    local data = PetData.GetData()
    if not data or not data.have then return 0 end

    for uuid, petInfo in pairs(data.have) do
        if petInfo.Type == "Pet" and not petInfo.Lock and not petInfo.Locked then
            pcall(function() DeleteRE:FireServer(uuid) end)
            soldCount += 1
        end
    end
    return soldCount
end

local function autoSellLoop()
    while State.AutoSell do
        sellAllPets()
        task.wait(2)
    end
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local savedMaxHP

local function godLoop()
    while State.GodMode do
        local hp = LocalPlayer:FindFirstChild("HPValue")
        if hp then
            if savedMaxHP == nil then savedMaxHP = hp:GetAttribute("MaxHP") end
            pcall(function()
                hp.Value = math.huge
                hp:SetAttribute("MaxHP", math.huge)
            end)
        end
        task.wait(0.25)
    end

    local hp = LocalPlayer:FindFirstChild("HPValue")
    if hp and savedMaxHP ~= nil then
        pcall(function()
            hp:SetAttribute("MaxHP", savedMaxHP)
            if type(savedMaxHP) == "number" then hp.Value = savedMaxHP end
        end)
    end
    savedMaxHP = nil
end

local function autoKillLoop()
    local enemies = Workspace:WaitForChild("EnemyFolder", 5)
    if not enemies then
        warn("[LazyJiro] EnemyFolder not found")
        State.AutoKill = false
        return
    end
    while State.AutoKill do
        for _, enemy in ipairs(enemies:GetChildren()) do
            local hpValue = enemy:FindFirstChild("HPValue")
            if hpValue and hpValue:IsA("ValueBase") and hpValue.Value > 0 then
                pcall(function() hpValue.Value = 0 end)
            end
        end
        task.wait(0.1)
    end
end

local Window = Lib:CreateWindow({
    Name      = "Lazy Jiro",
    ToggleKey = Enum.KeyCode.RightShift,
    Link      = "https://github.com/jiroscriptsss/LazyHub",
})

if (Lib.Version or 0) < 4 then
    warn("[LazyJiro] LazyJiroUI.lua on GitHub is outdated. Upload the new one, wait a few minutes, then run again.")
    Window:Notify({ Title = "Update needed", Content = "LazyJiroUI.lua on GitHub is outdated. Upload the new file, wait a few minutes, then run again.", Duration = 12 })
    Intro.Close()
    return
end

Intro.Set("Loading features", 0.6)

Window:AddCategory("Main")
local Main = Window:AddPage({ Name = "Farm" })

local Farming = Main:AddTab("Farming")

local Shared = {}

do
    local FarmCfg = {
        LoadTimeout = 30, RemoteTimeout = 10, RequireTimeout = 3,
        MaxFailures = 5, FailWindow = 10, RetryBase = 0.25, RetryMax = 2,
        KillAuraInterval = 0.25, KillDamage = 1e30,
    }

    local Farm = {
        Alive = true, Lock = nil, CollectBusy = false, OreBatch = nil, RetryNotified = false,
        Failures = {}, Loops = {}, Toggles = {},
        Opt = { CollectOre = false, Stage = nil, CollectRarities = {}, FarmWorkers = 24, KillAura = false, SuperLootAura = false },
    }

    local function notify(text, title)
        pcall(function() Window:Notify({ Title = title or "Stage & Combat", Content = text, Duration = 4 }) end)
    end

    local function Cfg()
        local folder = ReplicatedStorage:WaitForChild("Config", FarmCfg.LoadTimeout)
        if not folder then error("ReplicatedStorage.Config not found", 0) end
        return folder
    end

    local Util = {}
    function Util.Try(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[LazyJiro]", err) end
        return ok, err
    end
    function Util.Tier(id) return tonumber(tostring(id):match("%d+")) or 0 end

    local GameLib = { Loaded = {}, Failed = {}, Apis = {}, Deferred = {} }

    function GameLib.RequireAsGame(module)
        local done, ok, loaded = false, false, nil
        task.spawn(function()
            pcall(setthreadidentity, 2)
            local read, identity = pcall(getthreadidentity)
            if read and identity == 2 then
                ok, loaded = pcall(require, module)
            end
            done = true
        end)
        local deadline = os.clock() + FarmCfg.RequireTimeout
        while not done and os.clock() < deadline do task.wait() end
        return ok, loaded
    end

    function GameLib.Require(module)
        local cached = GameLib.Loaded[module]
        if cached ~= nil or GameLib.Failed[module] then return cached end
        local ok, loaded = pcall(require, module)
        if not ok then
            local firstErr = loaded
            ok, loaded = GameLib.RequireAsGame(module)
            if not ok then
                GameLib.Failed[module] = tostring(firstErr)
                warn("[LazyJiro] require", module:GetFullName(), firstErr)
                return nil
            end
        end
        GameLib.Loaded[module] = loaded
        return loaded
    end

    function GameLib.CallAsGame(fn, ...)
        local args = table.pack(...)
        local box
        task.defer(function()
            pcall(setthreadidentity, 2)
            box = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
        end)
        local deadline = os.clock() + FarmCfg.RequireTimeout
        while not box and os.clock() < deadline do task.wait() end
        if not box then return false, "game call timed out" end
        return table.unpack(box, 1, box.n)
    end

    function GameLib.Call(fn, ...)
        if not GameLib.Deferred[fn] then
            local result = table.pack(pcall(fn, ...))
            if result[1] or not tostring(result[2]):find("non-RobloxScript", 1, true) then
                if not result[1] then error(result[2], 0) end
                return table.unpack(result, 2, result.n)
            end
            GameLib.Deferred[fn] = true
        end
        local result = table.pack(GameLib.CallAsGame(fn, ...))
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end

    function GameLib.Need(module)
        local loaded = GameLib.Require(module)
        if loaded == nil then
            error(("game data %s.%s can't be read on this executor"):format(module.Parent.Name, module.Name), 0)
        end
        return loaded
    end

    function GameLib.Api(module)
        local api = GameLib.Apis[module]
        if api then return api end
        local loaded = GameLib.Need(module)
        api = setmetatable({}, {
            __index = function(self, key)
                local value = loaded[key]
                if type(value) ~= "function" then return value end
                local wrapped = function(...) return GameLib.Call(value, ...) end
                rawset(self, key, wrapped)
                return wrapped
            end,
        })
        GameLib.Apis[module] = api
        return api
    end

    do
        local REMOTE_CLASSES = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }
        local GENERIC = { try = true, re = true, rf = true, event = true, func = true, ["function"] = true, remote = true, request = true, once = true }
        local SYNONYM = {
            into = "enter", enter = "enter", join = "enter",
            exit = "exit", leave = "exit", quit = "exit",
            finish = "finish", finished = "finish", complete = "finish", completed = "finish",
            claim = "claim", claimed = "claim",
        }

        local function Tokens(name)
            local text = name:gsub("R[EF]$", ""):gsub("Events?$", ""):gsub("Functions?$", ""):gsub("Func$", "")
            text = text:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
            local set, size = {}, 0
            for word in text:lower():gmatch("%w+") do
                word = SYNONYM[word] or word
                if not GENERIC[word] and not set[word] then
                    set[word] = true
                    size += 1
                end
            end
            return set, size
        end

        local function Subset(a, b)
            for token in pairs(a) do
                if not b[token] then return false end
            end
            return true
        end

        local function ClassFits(name, className)
            if name:find("RF$") or name:find("Function$") then return className == "RemoteFunction" end
            if name:find("RE$") or name:find("Event$") then return className ~= "RemoteFunction" end
            return true
        end

        local index, indexAt = {}, -10
        local function Index()
            if os.clock() - indexAt < 2 then return index end
            indexAt = os.clock()
            local list = {}
            local root = ReplicatedStorage:FindFirstChild("Remote")
            local ok, all = pcall(function() return ReplicatedStorage:GetDescendants() end)
            for _, inst in ipairs(ok and all or {}) do
                if REMOTE_CLASSES[inst.ClassName] then
                    local tokens, size = Tokens(inst.Name)
                    list[#list + 1] = {
                        Inst = inst, Name = inst.Name, Class = inst.ClassName,
                        Folder = inst.Parent and inst.Parent.Name or "",
                        Path = inst:GetFullName():lower(),
                        Tokens = tokens, Size = size,
                        InRemote = root ~= nil and inst:IsDescendantOf(root),
                    }
                end
            end
            index = list
            return list
        end

        local function Resolve(folder, name)
            local want, wantSize = Tokens(name)
            if wantSize == 0 then return nil end
            local folderKey = folder:lower()
            local best, bestScore, second = nil, 0, 0
            for _, c in ipairs(Index()) do
                if ClassFits(name, c.Class) then
                    local sameFolder = c.Folder:lower() == folderKey
                    local inPath = c.Path:find(folderKey, 1, true) ~= nil
                    local score = 0
                    if c.Name == name then
                        score = 100
                    elseif c.Size > 0 and (Subset(want, c.Tokens) or Subset(c.Tokens, want)) then
                        local common = 0
                        for token in pairs(want) do
                            if c.Tokens[token] then common += 1 end
                        end
                        if c.Size == wantSize or inPath or math.min(c.Size, wantSize) > 1 then
                            score = 50 + 30 * common / (wantSize + c.Size - common)
                        end
                    end
                    if score > 0 then
                        if sameFolder then score += 20 elseif inPath then score += 10 end
                        if c.InRemote then score += 5 end
                        if score > bestScore then
                            second = bestScore
                            best, bestScore = c, score
                        elseif score > second and c.Inst ~= best.Inst then
                            second = score
                        end
                    end
                end
            end
            if best and bestScore >= 60 and bestScore - second >= 5 then return best.Inst end
            return nil
        end

        local resolved, missUntil, announced, deadUntil = {}, {}, {}, {}

        function Util.FindRemote(folder, name)
            local root = ReplicatedStorage:FindFirstChild("Remote")
            if not root then return nil end
            local holder = root:FindFirstChild(folder)
            local direct = holder and holder:FindFirstChild(name)
            if direct then return direct end

            local key = folder .. "." .. name
            local cached = resolved[key]
            if cached and cached.Parent then return cached end
            if (missUntil[key] or 0) > os.clock() then return nil end

            local hit = Resolve(folder, name)
            if hit then
                resolved[key] = hit
                if not announced[key] then
                    announced[key] = true
                    print(("[LazyJiro] remote %s -> %s"):format(key, hit:GetFullName()))
                end
                return hit
            end
            missUntil[key] = os.clock() + 3
            return nil
        end

        function Util.Remote(folder, name)
            local remote = Util.FindRemote(folder, name)
            if remote then return remote end
            local key = folder .. "." .. name
            if (deadUntil[key] or 0) > os.clock() then
                error(("remote %s not found"):format(key), 0)
            end
            local deadline = os.clock() + FarmCfg.RemoteTimeout
            while not remote and os.clock() < deadline do
                task.wait(0.25)
                missUntil[key] = nil
                remote = Util.FindRemote(folder, name)
            end
            if remote then return remote end
            deadUntil[key] = os.clock() + 30
            error(("remote %s not found"):format(key), 0)
        end
    end

    local Sched = {}

    function Sched.Run(key, fn)
        if not Farm.Alive or not Farm.Opt[key] then return false end
        local failures = Farm.Failures
        local streak = failures[key]
        local now = os.clock()
        if streak and now < (streak.nextTry or 0) then return false end
        local ok, result = pcall(fn)
        if ok then failures[key] = nil; return true, result end
        now = os.clock()
        if not streak then
            streak = { count = 0, since = now }
            failures[key] = streak
            warn("[LazyJiro]", key, tostring(result))
        end
        streak.count += 1
        streak.nextTry = now + math.min(FarmCfg.RetryMax, FarmCfg.RetryBase * 2 ^ math.min(streak.count - 1, 8))
        if streak.count >= FarmCfg.MaxFailures and now - streak.since >= FarmCfg.FailWindow then
            failures[key] = nil
            Farm.Opt[key] = false
            local reason = tostring(result):match("[^\n]*")
            warn("[LazyJiro]", key, "stopped:", reason)
            local toggle = Farm.Toggles[key]
            if toggle then toggle:Set(false, true) end
            notify(key .. " stopped: " .. reason, "Warning")
        end
        return false, result
    end

    function Sched.StartLoop(key, fn, interval, minimum)
        if Farm.Loops[key] then return end
        Farm.Loops[key] = true
        task.spawn(function()
            local ok, err = pcall(function()
                while Farm.Alive do
                    local started = os.clock()
                    if Farm.Opt[key] then Sched.Run(key, fn) end
                    local delay = Farm.Opt[key] and interval() or 0.1
                    local period = math.max(minimum == nil and 0.04 or minimum, tonumber(delay) or 0.1)
                    local elapsed = os.clock() - started
                    task.wait(elapsed < period and math.max(0.001, period - elapsed) or period)
                end
            end)
            Farm.Loops[key] = nil
            if not ok then warn("[LazyJiro]", key, err) end
        end)
    end

    local function Exclusive(name, fn, ...)
        if Farm.Lock then return false end
        Farm.Lock = name
        local ok, result = Util.Try(fn, ...)
        Farm.Lock = nil
        return ok, result
    end

    local Ore, Stage = {}, {}

    function Ore.Rarity(oreId)
        local configs = GameLib.Need(Cfg().Ore.Config)
        local oreConfig = configs[oreId] or configs[tostring(oreId)]
        local numeric = tonumber(oreId)
        if not oreConfig and numeric then oreConfig = configs[numeric] end
        if not oreConfig then return nil end
        return GameLib.Api(Cfg().Rarity.Helper).GetRarityByLevel(tonumber(oreConfig.Rarity) or oreConfig.Rarity)
    end

    function Ore.Allows(rarities, name)
        if not rarities then return true end
        if not name then return false end
        if rarities[name] then return true end
        local wanted = tostring(name):lower():match("^%s*(.-)%s*$")
        for key, selected in pairs(rarities) do
            local value = type(key) == "number" and selected or key
            if selected and tostring(value):lower():match("^%s*(.-)%s*$") == wanted then return true end
        end
        return false
    end

    local function RarityNames()
        local helper = GameLib.Api(Cfg().Rarity.Helper)
        local names = {}
        for level = 1, 20 do
            local ok, name = pcall(helper.GetRarityByLevel, level)
            if not ok or not name then break end
            table.insert(names, name)
        end
        return names
    end

    function Stage.List()
        local stages = {}
        for stageId in pairs(GameLib.Api(Cfg().Stage.Helper).GetStageEnemyConfig()) do
            table.insert(stages, stageId)
        end
        table.sort(stages, function(a, b) return Util.Tier(a) > Util.Tier(b) end)
        return stages
    end

    function Stage.Best() return Stage.List()[1] end

    function Stage.Collect(stageId, rarities, keepRunning)
        local function active()
            return Farm.Alive and (not keepRunning or keepRunning())
        end
        while Farm.CollectBusy do
            if not active() then return end
            task.wait(0.01)
        end
        if not active() or not stageId then return end
        Farm.CollectBusy = true
        local ok, result = pcall(function()
            local batch = Farm.OreBatch
            if not batch then
                local drops = Util.Remote("Stage", "StageFinishedRF"):InvokeServer(stageId)
                if type(drops) ~= "table" then error("Stage did not return a loot batch", 0) end
                batch = { stage = stageId, drops = drops, ores = {}, stones = {}, done = {}, rarities = rarities and table.clone(rarities) }
                Farm.OreBatch = batch
            end
            if not rarities and batch.rarities then rarities = batch.rarities end
            if not batch.classified then
                local ores, stones = {}, {}
                local configs = GameLib.Need(Cfg().Ore.Config)
                for uuid, drop in pairs(batch.drops) do
                    if type(drop) == "table" then
                        table.insert(stones, uuid)
                    else
                        local rarity = Ore.Rarity(drop)
                        if rarities and not rarity then error("Cannot resolve ore rarity: " .. tostring(drop), 0) end
                        local config = configs[drop] or configs[tostring(drop)] or configs[tonumber(drop)]
                        table.insert(ores, { uuid = uuid, rarity = rarity, rank = tonumber(config and config.Rarity) or 0 })
                    end
                end
                table.sort(ores, function(left, right)
                    if left.rank ~= right.rank then return left.rank > right.rank end
                    return tostring(left.uuid) < tostring(right.uuid)
                end)
                batch.ores, batch.stones, batch.classified = ores, stones, true
            end
            if not active() then return end
            if #batch.stones > 0 then
                local pickStone = Util.Remote("Stage", "GetEnhantStoneRE")
                for _, uuid in ipairs(batch.stones) do
                    if not active() then return end
                    if not batch.done[uuid] then
                        pickStone:FireServer(uuid)
                        batch.done[uuid] = true
                    end
                end
            end
            local ores = {}
            for _, ore in ipairs(batch.ores) do
                if not batch.done[ore.uuid] and Ore.Allows(rarities, ore.rarity) then table.insert(ores, ore.uuid) end
            end
            if #ores > 0 then
                local pickOre = Util.Remote("Stage", "GetOreRF")
                local workers = math.min(#ores, math.clamp(math.floor(tonumber(Farm.Opt.FarmWorkers) or 24), 1, 32))
                local nextOre, pending, failure = 1, workers, nil
                local completion = Instance.new("BindableEvent")
                for _ = 1, workers do
                    task.spawn(function()
                        local worked, err = pcall(function()
                            while active() do
                                local idx = nextOre
                                nextOre += 1
                                if idx > #ores then break end
                                local uuid = ores[idx]
                                local lastError
                                for attempt = 1, 3 do
                                    if not active() then break end
                                    local accepted, response = pcall(pickOre.InvokeServer, pickOre, uuid)
                                    if accepted and response ~= false then
                                        batch.done[uuid] = true
                                        lastError = nil
                                        break
                                    end
                                    lastError = accepted and "Ore pickup was rejected" or response
                                    if attempt < 3 and active() then task.wait(0.02 * attempt) end
                                end
                                if lastError then failure = failure or lastError end
                            end
                        end)
                        if not worked then failure = failure or err end
                        pending -= 1
                        if pending == 0 then completion:Fire() end
                    end)
                end
                if pending > 0 then completion.Event:Wait() end
                completion:Destroy()
                if failure then error(failure, 0) end
            end
            if not active() then return end
            Util.Remote("Stage", "ClaimedAllOreRE"):FireServer()
            Farm.OreBatch = nil
        end)
        Farm.CollectBusy = false
        if not ok then
            if keepRunning and not Farm.RetryNotified then
                Farm.RetryNotified = true
                notify("Ore pickup delayed; unfinished selected ore will be retried", "Warning")
            end
            error(result, 0)
        end
        if not Farm.OreBatch and Farm.RetryNotified then
            Farm.RetryNotified = false
            notify("Pending selected ore batch completed", "Success")
        end
    end

    function Stage.StartCollecting()
        Sched.StartLoop("CollectOre", function()
            if Farm.Lock then return end
            local selected = false
            for _, enabled in pairs(Farm.Opt.CollectRarities or {}) do
                if enabled then selected = true; break end
            end
            if not selected then return end
            local ok, err = Exclusive("Farm", function()
                Stage.Collect(Farm.Opt.Stage or Stage.Best(), Farm.Opt.CollectRarities, function() return Farm.Opt.CollectOre end)
            end)
            if not ok and err ~= nil then error(err, 0) end
        end, function() return 0 end, 0)
    end

    function Stage.ExitFight()
        GameLib.Api(LocalPlayer.PlayerScripts.Manager.StageManager.StageUtils).ExitFight(true)
    end

    local function KillAll()
        local folder = workspace:FindFirstChild("EnemyFolder")
        if not folder then return false end
        local hit = GameLib.Api(ReplicatedStorage.Utils.CommunicationUtils).TryGetBindableEvent("Attack", "EnemyHitBE")
        local hitInfo = { SkillID = "K_ATK_1", IsCrit = true, Damage = FarmCfg.KillDamage }
        for _, enemy in ipairs(folder:GetChildren()) do
            local enemyId = enemy:GetAttribute("EnemyID")
            if enemyId and not enemyId:find("^Super") then
                hit:Fire(enemy.Name, FarmCfg.KillDamage, hitInfo)
            end
        end
    end

    local function SuperKill(uuid)
        Util.Remote("SuperLoot", "KillSuperLootRE"):FireServer(uuid)
        task.wait(0.2)
        Util.Remote("Stage", "GetOreRF"):InvokeServer(uuid)
        Util.Remote("Stage", "ClaimedAllOreRE"):FireServer()
    end

    local function SuperKillExisting()
        local folder = workspace:FindFirstChild("EnemyFolder")
        if not folder then return end
        for _, enemy in ipairs(folder:GetChildren()) do
            local enemyId = enemy:GetAttribute("EnemyID")
            if enemyId and enemyId:find("^Super") then
                task.spawn(Util.Try, SuperKill, enemy.Name)
            end
        end
    end

    local StageCard = Farming:AddCard("Stage", "Left")
    local CombatCard = Farming:AddCard("Combat", "Right")

    local stageDropdown = StageCard:AddDropdown({ Name = "Stage", Options = { "Loading..." }, Default = "Loading...", Callback = function(v)
        if v ~= "Loading..." and v ~= "Unavailable" then Farm.Opt.Stage = v end
    end })

    Farm.Toggles.CollectOre = StageCard:AddToggle({ Name = "Auto Collect Ore", Default = false, Callback = function(v)
        Farm.Opt.CollectOre = v
        Farm.Failures.CollectOre = nil
        if v then
            Stage.StartCollecting()
            notify("Ore farm started: selected rarities only", "Success")
        else
            notify("Ore farm paused; pending requests will finish")
        end
    end })

    StageCard:AddSlider({ Name = "Ore pickup workers", Min = 1, Max = 32, Default = 24, Increment = 1, Callback = function(v)
        Farm.Opt.FarmWorkers = v
    end })

    local rarityDropdown = StageCard:AddDropdown({ Name = "Ore Rarity Filter", Multi = true, Options = { "Loading..." }, Default = {}, Callback = function(set)
        set["Loading..."] = nil
        Farm.Opt.CollectRarities = set
    end })

    task.spawn(function()
        local ok, stages = pcall(Stage.List)
        if ok and type(stages) == "table" and #stages > 0 then
            stageDropdown:Refresh(stages)
            stageDropdown:Set(stages[1])
        else
            warn("[LazyJiro] stage list:", stages)
            stageDropdown:Refresh({ "Unavailable" })
            stageDropdown:Set("Unavailable", true)
            notify("Stage list could not be read. Auto Collect Ore will use the best stage if it can")
        end
    end)

    task.spawn(function()
        local ok, names = pcall(RarityNames)
        if ok and type(names) == "table" and #names > 0 then
            rarityDropdown:Refresh(names)
            rarityDropdown:Set(names)
        else
            warn("[LazyJiro] rarity list:", names)
            rarityDropdown:Refresh({ "Unavailable" })
            rarityDropdown:Set({}, true)
            notify("Rarity list could not be read, so Auto Collect Ore can't filter ores")
        end
    end)

    Farm.Toggles.KillAura = CombatCard:AddToggle({ Name = "Kill Aura", Default = false, Callback = function(v)
        Farm.Opt.KillAura = v
        Farm.Failures.KillAura = nil
        if not v then return end
        local ok = pcall(function() return GameLib.Need(ReplicatedStorage.Utils.CommunicationUtils) end)
        if not ok then
            Farm.Opt.KillAura = false
            Farm.Toggles.KillAura:Set(false, true)
            notify("Kill Aura is not available on this executor", "Warning")
            return
        end
        Sched.StartLoop("KillAura", KillAll, function() return FarmCfg.KillAuraInterval end)
    end })

    Farm.Toggles.SuperLootAura = CombatCard:AddToggle({ Name = "Kill Ore Boss", Default = false, Callback = function(v)
        Farm.Opt.SuperLootAura = v
        if v then SuperKillExisting() end
    end })

    CombatCard:AddButton({ Name = "Exit Fight Now", Primary = true, Callback = function()
        local ok, err = pcall(Stage.ExitFight)
        if ok then
            notify("Left the fight")
        else
            warn("[LazyJiro] exit fight:", err)
            notify("Could not exit the fight", "Warning")
        end
    end })

    CombatCard:AddToggle({ Name = "Infinite HP", Default = false, Callback = function(v)
        State.GodMode = v
        if v then task.spawn(godLoop) end
    end })

    CombatCard:AddToggle({ Name = "Auto Kill Enemies", Default = false, Callback = function(v)
        State.AutoKill = v
        if v then task.spawn(autoKillLoop) end
    end })

    task.spawn(function()
        local ok, err = pcall(function()
            local event = Util.Remote("SuperLoot", "RefreshSuperLootRE")
            Window.reg(event.OnClientEvent:Connect(function(_, uuid)
                if Farm.Opt.SuperLootAura then
                    task.spawn(Util.Try, SuperKill, uuid)
                end
            end))
        end)
        if not ok then warn("[LazyJiro] ore boss hook:", err) end
    end)

    Window.reg({ Disconnect = function() Farm.Alive = false end })

    Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify = Util, GameLib, Cfg, notify
    Shared.Ore, Shared.Stage, Shared.Farm, Shared.RarityNames = Ore, Stage, Farm, RarityNames
end

do
    local Util, GameLib, notify = Shared.Util, Shared.GameLib, Shared.notify
    local Stage = Shared.Stage
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")

    local BC = {
        SaveFolder = "Lazy Jiro",

        ReloadSource = [[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)
local url = "https://raw.githubusercontent.com/jiroscriptsss/LazyHub/main/Loader.lua"
local ok, body = pcall(game.HttpGet, game, url)
if not (ok and type(body) == "string") then
    local requester = request or http_request or (syn and syn.request) or (http and http.request)
    local sent, reply = pcall(requester, { Url = url, Method = "GET" })
    body = sent and type(reply) == "table" and reply.Body
end
if type(body) == "string" then loadstring(body)() end]],
        MaxFailures = 5, RetryBase = 0.25, RetryMax = 2,
        BossCards = 8,
        BossAttackIds = { Katana = "K_ATK_1", Great = "G_ATK_1" },
        BossHitsPerTick = 30, BossHitGap = 0.02, BossJoinSettle = 1, BossClaimDelay = 3.5,
        BossStandHeight = 3, BossStandBack = 8, BossReach = 25,
        BossInterval = 1, BossHopInterval = 5, BossHopLead = 150, BossHopAfter = 8,
        BossHopFlag = "bosshop.txt", BossHopResume = 180, BossHopServers = "bossservers.json",
        HopListTtl = 120, HopBackoffStart = 5, HopBackoffMax = 60, HopGiveUp = 8, HopStall = 30, HopGap = 15,
    }

    local B = {
        Alive = true, Loops = {}, Fails = {}, Toggles = {},
        BossReturn = nil, BossDone = nil, BossExit = nil, BossExitWarned = false,
        BossHopping = false, HopFails = 0, HopBackoff = nil, HopBlockedUntil = 0, HopQueued = false,
        Opt = { AutoWorldBoss = false, BossCards = true, BossHop = false },
    }

    local function bnotify(text, title) notify(text, title or "World Boss") end

    local function HttpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" then return body end
        local send = request or http_request or (syn and syn.request) or (http and http.request)
        if not send then return nil end
        local sent, response = pcall(send, { Url = url, Method = "GET" })
        if sent and type(response) == "table" and response.StatusCode == 200 and type(response.Body) == "string" then
            return response.Body
        end
        return nil
    end

    local function AttackId()
        return BC.BossAttackIds[LocalPlayer:GetAttribute("WeaponType")]
    end

    local function Join()
        Util.Remote("WorldBoss", "IntoWorldBossFight"):FireServer()
        local char = LocalPlayer.Character
        if char and not B.BossReturn then B.BossReturn = char:GetPivot() end
    end

    local function StandNear(boss)
        local char = LocalPlayer.Character
        if not char then return end
        local pos = boss:GetPivot().Position
        if (char:GetPivot().Position - pos).Magnitude > BC.BossReach then
            char:PivotTo(CFrame.new(pos + Vector3.new(0, BC.BossStandHeight, BC.BossStandBack), pos))
        end
    end

    local function BossStep()
        local bossName = workspace:GetAttribute("CurrentWorldBoss")
        if not bossName then return end
        local attackId = AttackId()
        if not attackId then return end
        if LocalPlayer:GetAttribute("IntoFight") ~= "WorldBoss" then
            Join()
            task.wait(BC.BossJoinSettle)
        end

        local enemyFolder = workspace:FindFirstChild("EnemyFolder_Server") or workspace:FindFirstChild("EnemyFolder")
        local boss = enemyFolder and enemyFolder:FindFirstChild(bossName)
        if not boss or boss:GetAttribute("Dead") then return end
        StandNear(boss)
        local announce = Util.Remote("Attack", "UseAnyATKRE")
        local attack = Util.Remote("Attack", "AttackEnemyServiceRE")
        for _ = 1, BC.BossHitsPerTick do
            if not (B.Opt.AutoWorldBoss and boss.Parent) then return end
            announce:FireServer(attackId, workspace:GetServerTimeNow())
            attack:FireServer({ bossName }, { Phase = 1, SkillID = attackId, Attacker = LocalPlayer }, workspace:GetServerTimeNow())
            task.wait(BC.BossHitGap)
        end
    end

    local function ClaimCards()
        local claim = Util.FindRemote("WorldBoss", "TryClaimBossRewardRE")
        if not claim then return end
        for card = 1, BC.BossCards do
            if claim.ClassName == "RemoteFunction" then
                task.spawn(claim.InvokeServer, claim, tostring(card))
            else
                task.spawn(claim.FireServer, claim, tostring(card))
            end
        end
    end

    local ExitWords = { exit = true, leave = true, quit = true, out = true, back = true, ["end"] = true, finish = true, ["return"] = true }
    local SkipWords = { into = true, enter = true, join = true, dead = true, escape = true, claim = true, reward = true, attack = true, atk = true, cards = true, card = true, tick = true }

    local function NameWords(name)
        local words = {}
        for word in name:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"):lower():gmatch("%a+") do
            words[#words + 1] = word
        end
        return words
    end

    local function ExitRemote()
        local cached = B.BossExit
        if cached and cached.Parent then return cached end
        B.BossExit = nil

        local direct = Util.FindRemote("WorldBoss", "ExitWorldBossFight")
        if direct then
            B.BossExit = direct
            return direct
        end

        local best, bestScore = nil, 0
        local ok, all = pcall(function() return ReplicatedStorage:GetDescendants() end)
        for _, inst in ipairs(ok and all or {}) do
            local class = inst.ClassName
            if class == "RemoteEvent" or class == "RemoteFunction" or class == "UnreliableRemoteEvent" then
                if inst:GetFullName():lower():find("boss", 1, true) then
                    local isExit, skip, score = false, false, 0
                    for _, word in ipairs(NameWords(inst.Name)) do
                        if ExitWords[word] then isExit = true; score += 10 end
                        if SkipWords[word] then skip = true end
                        if word == "boss" then score += 3 elseif word == "world" or word == "fight" then score += 1 end
                    end
                    if isExit and not skip then
                        if inst.Parent and inst.Parent.Name:lower():find("boss", 1, true) then score += 5 end
                        if score > bestScore or (score == bestScore and best and inst:GetFullName() < best:GetFullName()) then
                            best, bestScore = inst, score
                        end
                    end
                end
            end
        end
        if best then
            B.BossExit = best
            print(("[LazyJiro] boss exit remote -> %s"):format(best:GetFullName()))
        end
        return best
    end

    local function Leave()
        local exit = ExitRemote()
        if exit then
            if exit.ClassName == "RemoteFunction" then
                task.spawn(function() pcall(exit.InvokeServer, exit) end)
            else
                pcall(exit.FireServer, exit)
            end
        else
            if not B.BossExitWarned then
                B.BossExitWarned = true
                warn("[LazyJiro] boss exit remote not found, using the game's own ExitFight instead")
            end
            pcall(Stage.ExitFight)
        end
        LocalPlayer:SetAttribute("IntoFight", nil)
        local char = LocalPlayer.Character
        if B.BossReturn and char then char:PivotTo(B.BossReturn) end
        B.BossReturn = nil
    end

    local function HopFlag(enabled)
        local flag = BC.SaveFolder .. "/" .. BC.BossHopFlag
        pcall(function()
            if enabled then
                if not isfolder(BC.SaveFolder) then makefolder(BC.SaveFolder) end
                writefile(flag, tostring(os.time()))
            elseif isfile(flag) then
                delfile(flag)
            end
        end)
    end

    local function SinceLastHop()
        local ok, stamp = pcall(readfile, BC.SaveFolder .. "/" .. BC.BossHopFlag)
        if not ok or not tonumber(stamp) then return nil end
        return os.time() - tonumber(stamp)
    end

    local function HopWanted()
        local since = SinceLastHop()
        return since ~= nil and since < BC.BossHopResume
    end

    local function LoadServers()
        local ok, text = pcall(readfile, BC.SaveFolder .. "/" .. BC.BossHopServers)
        if not ok then return {}, 0 end
        local decoded
        ok, decoded = pcall(HttpService.JSONDecode, HttpService, text)
        if not ok or type(decoded) ~= "table" or type(decoded.ids) ~= "table" then return {}, 0 end
        local fetchedAt = tonumber(decoded.at) or 0
        if os.time() - fetchedAt > BC.HopListTtl then return {}, 0 end
        return decoded.ids, fetchedAt
    end

    local function SaveServers(ids, fetchedAt)
        pcall(function()
            if not isfolder(BC.SaveFolder) then makefolder(BC.SaveFolder) end
            writefile(BC.SaveFolder .. "/" .. BC.BossHopServers, HttpService:JSONEncode({ at = fetchedAt, ids = ids }))
        end)
    end

    local function FetchServers()
        if os.clock() < B.HopBlockedUntil then return {} end
        local body = HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
        local ok, list = pcall(HttpService.JSONDecode, HttpService, body or "")
        local ids = {}
        for _, server in ipairs(ok and type(list) == "table" and type(list.data) == "table" and list.data or {}) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(ids, server.id) end
        end
        if #ids > 0 then
            B.HopFails, B.HopBackoff = 0, nil
            return ids
        end
        B.HopFails += 1
        B.HopBackoff = math.min((B.HopBackoff or BC.HopBackoffStart / 2) * 2, BC.HopBackoffMax)
        B.HopBlockedUntil = os.clock() + B.HopBackoff
        warn("[LazyJiro] server list refused, retry in", B.HopBackoff, "s, fail", B.HopFails)
        return {}
    end

    local function PickServer()
        local ids, fetchedAt = LoadServers()
        if #ids == 0 then
            ids, fetchedAt = FetchServers(), os.time()
        end
        while #ids > 0 do
            local serverId = table.remove(ids, math.random(#ids))
            if serverId ~= game.JobId then
                SaveServers(ids, fetchedAt)
                return serverId
            end
        end
        SaveServers(ids, fetchedAt)
        return nil
    end

    local function Hop()
        local serverId = PickServer()
        if not serverId then return end
        B.BossHopping = os.clock()
        HopFlag(true)
        local queue = queue_on_teleport or queueonteleport
        if queue and not B.HopQueued then
            queue(BC.ReloadSource)
            B.HopQueued = true
        end
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
    end

    local function WorthStaying()
        local boss = workspace:GetAttribute("CurrentWorldBoss")
        if boss and not B.BossDone then return true end
        if B.BossDone then return os.clock() - B.BossDone < BC.BossHopAfter end
        local nextTick, serverTime = workspace:GetAttribute("NextWorldBossTick"), workspace:GetAttribute("ServerTime")
        if not nextTick or not serverTime then return true end
        return nextTick - serverTime <= BC.BossHopLead
    end

    local function HopGiveUp()
        B.Opt.BossHop = false
        HopFlag(false)
        if B.Toggles.BossHop then B.Toggles.BossHop:Set(false, true) end
        bnotify("Boss Server Hop stopped: no server list from Roblox, try again later", "Warning")
    end

    local function HopStep()
        if B.BossHopping then
            if os.clock() - B.BossHopping < BC.HopStall then return end
            B.BossHopping = false
        end
        if WorthStaying() then return end
        if (SinceLastHop() or BC.HopGap) < BC.HopGap then return end
        if B.HopFails >= BC.HopGiveUp then
            HopGiveUp()
            return
        end
        Hop()
    end

    local function Run(key, fn)
        if not B.Alive or not B.Opt[key] then return end
        local ok, err = pcall(fn)
        if ok then B.Fails[key] = nil; return end
        local fails = (B.Fails[key] or 0) + 1
        B.Fails[key] = fails
        if fails == 1 then warn("[LazyJiro]", key, tostring(err)) end
        if fails >= BC.MaxFailures then
            B.Fails[key] = nil
            B.Opt[key] = false
            local reason = tostring(err):match("[^\n]*")
            warn("[LazyJiro]", key, "stopped:", reason)
            local toggle = B.Toggles[key]
            if toggle then toggle:Set(false, true) end
            bnotify(key .. " stopped: " .. reason, "Warning")
            return
        end
        task.wait(math.min(BC.RetryMax, BC.RetryBase * 2 ^ (fails - 1)))
    end

    local function StartLoop(key, interval, fn)
        if B.Loops[key] then return end
        B.Loops[key] = true
        task.spawn(function()
            while B.Alive do
                local started = os.clock()
                if B.Opt[key] then Run(key, fn) end
                local period = math.max(0.04, B.Opt[key] and interval or 0.1)
                local elapsed = os.clock() - started
                task.wait(elapsed < period and math.max(0.001, period - elapsed) or period)
            end
            B.Loops[key] = nil
        end)
    end

    local BossCard = Farming:AddCard("World Boss", "Left")

    B.Toggles.AutoWorldBoss = BossCard:AddToggle({
        Name = "Auto World Boss", Description = "Joins every world boss and kills it", Default = false,
        Callback = function(v)
            B.Opt.AutoWorldBoss = v
            B.Fails.AutoWorldBoss = nil
            if v then
                StartLoop("AutoWorldBoss", BC.BossInterval, BossStep)
            elseif LocalPlayer:GetAttribute("IntoFight") == "WorldBoss" then
                task.spawn(Util.Try, Leave)
            end
        end,
    })

    BossCard:AddToggle({ Name = "Take every reward card", Default = true, Callback = function(v)
        B.Opt.BossCards = v
    end })

    B.Toggles.BossHop = BossCard:AddToggle({
        Name = "Boss Server Hop",
        Description = "Hops to servers where the boss is up or about to spawn, kills it, then moves on",
        Default = false,
        Callback = function(v)
            B.Opt.BossHop = v
            B.Fails.BossHop = nil
            HopFlag(v)
            if v then
                local main = B.Toggles.AutoWorldBoss
                if main and not main.Value then main:Set(true) end
                StartLoop("BossHop", BC.BossHopInterval, HopStep)
            end
        end,
    })

    task.spawn(function()
        local ok, err = pcall(function()
            local dead = Util.Remote("WorldBoss", "BossDeadRE")
            Window.reg(dead.OnClientEvent:Connect(function()
                if not B.Opt.AutoWorldBoss then return end
                task.delay(BC.BossClaimDelay, function()
                    if B.Opt.BossCards then Util.Try(ClaimCards) end
                    Util.Try(Leave)
                    B.BossDone = os.clock()
                end)
            end))
            local escape = Util.FindRemote("WorldBoss", "BossEscapeRE")
            if escape and escape.ClassName ~= "RemoteFunction" then
                Window.reg(escape.OnClientEvent:Connect(function()
                    if B.Opt.AutoWorldBoss then Util.Try(Leave) end
                end))
            end
        end)
        if not ok then warn("[LazyJiro] boss hook:", err) end
    end)

    Window.reg(TeleportService.TeleportInitFailed:Connect(function()
        if not B.BossHopping then return end
        B.BossHopping = false
        task.delay(1, Util.Try, HopStep)
    end))

    task.defer(function()
        if HopWanted() and B.Toggles.BossHop then B.Toggles.BossHop:Set(true) end
    end)

    Window.reg({ Disconnect = function()
        B.Alive = false
        if LocalPlayer:GetAttribute("IntoFight") == "WorldBoss" then task.spawn(Util.Try, Leave) end
    end })
end

local SellPage = Window:AddPage({ Name = "Sell" })
local ForgePage = Window:AddPage({ Name = "Forge" })
local UpgradePage = Window:AddPage({ Name = "Upgrade" })
local ForgeTab = ForgePage:AddTab("Forge")
do
    local Util, GameLib, Cfg, notify = Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify
    local Ore, Stage, Farm = Shared.Ore, Shared.Stage, Shared.Farm

    local FC = {
        RefillAmount = 100000, AcquireRounds = 300, TickDelay = 0.2, MaxFailures = 5,
        ScoreLevel = 20, OwnedLabel = "Owned ores",
        Targets = {
            { name = "Great Weapon", forgeType = "Weapon", ores = 13 },
            { name = "Katana",       forgeType = "Weapon", ores = 4 },
            { name = "Armor",        forgeType = "Armor",  ores = 11 },
            { name = "Hat",          forgeType = "Armor",  ores = 4 },
        },
    }

    local F = {
        Alive = true, Busy = false, Running = false, Profile = nil, OreLabels = {}, OreStage = {},
        Opt = {
            AutoForge = false, ForgeTarget = "Great Weapon", ForgeOre = FC.OwnedLabel, ForgeRarities = {},
            KeepPerOre = 0, BestOreFirst = false, ForgePerTick = 10, SellJunk = false,
        },
    }

    local function fnotify(text) notify(text, "Forge") end

    local function GetProfile()
        F.Profile = Util.Remote("Profile", "GetTotalDataRF"):InvokeServer()
        return F.Profile
    end

    local function Count(profile, itemId)
        local total = 0
        for _, entry in pairs(profile.Backpack.have) do
            if entry.ID == itemId then total += entry.Number or 1 end
        end
        return total
    end

    local function Uuid(profile, itemId)
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.ID == itemId and (entry.Number or 0) >= 1 then return uuid end
        end
        return nil
    end

    local function Snapshot()
        local seen = {}
        for uuid in pairs(GetProfile().Backpack.have) do seen[uuid] = true end
        return seen
    end

    local function NewGear(before)
        local fresh = {}
        for uuid, entry in pairs(GetProfile().Backpack.have) do
            if not before[uuid] and entry.Type ~= "Ore" and entry.Type ~= "Material" and entry.Type ~= "EnchStone" then
                fresh[uuid] = entry
            end
        end
        return fresh
    end

    local function OreIds()
        local ids = {}
        for oreId in pairs(GameLib.Need(Cfg().Ore.Config)) do table.insert(ids, oreId) end
        table.sort(ids, function(a, b) return Util.Tier(a) > Util.Tier(b) end)
        return ids
    end

    local function HighestKey(configTable)
        local bestKey, bestTier = nil, -1
        for key in pairs(configTable) do
            local tier = Util.Tier(key)
            if tier > bestTier then bestKey, bestTier = key, tier end
        end
        return bestKey
    end

    local function OwnedOres(profile)
        local ores = {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.Type == "Ore" and (entry.Number or 0) >= 1 then
                table.insert(ores, {
                    uuid = uuid, id = entry.ID, tier = Util.Tier(entry.ID),
                    number = math.floor(entry.Number), rarity = Ore.Rarity(entry.ID),
                })
            end
        end
        table.sort(ores, function(a, b) return a.tier > b.tier end)
        return ores
    end

    local function OreChoices()
        local oreShow = GameLib.Need(Cfg().Ore.Show)
        local labels, idByLabel = { FC.OwnedLabel }, {}
        for _, oreId in ipairs(OreIds()) do
            local label = ("%s (%s)"):format(oreShow[oreId] and oreShow[oreId].DisplayName or oreId, Ore.Rarity(oreId) or "?")
            if idByLabel[label] then label = ("%s #%d"):format(label, Util.Tier(oreId)) end
            idByLabel[label] = oreId
            table.insert(labels, label)
        end
        F.OreLabels = idByLabel
        return labels
    end

    local function AddOre(uuid, amount)
        Util.Remote("Backpack", "TrySellItemRE"):FireServer(uuid, -math.abs(amount))
    end

    local function AcquireOre(oreId)

        local deadline = os.clock() + 5
        while (Farm.CollectBusy or Farm.OreBatch) and os.clock() < deadline do task.wait(0.1) end
        if Farm.CollectBusy or Farm.OreBatch then return false end

        local stages = Stage.List()
        if #stages == 0 then return false end
        local known = F.OreStage[oreId]
        local top = HighestKey(GameLib.Need(Cfg().Ore.Config))
        local target = Util.Tier(oreId) * #stages / math.max(1, Util.Tier(top))
        table.sort(stages, function(a, b)
            if a == b then return false end
            if a == known or b == known then return a == known end
            return math.abs(Util.Tier(a) - target) < math.abs(Util.Tier(b) - target)
        end)

        local finished = Util.Remote("Stage", "StageFinishedRF")
        local pickOre = Util.Remote("Stage", "GetOreRF")
        for round = 1, FC.AcquireRounds do
            if not F.Alive then return false end
            local stageId = stages[(round - 1) % math.min(#stages, 4) + 1]
            local drops = finished:InvokeServer(stageId)
            for uuid, drop in pairs(type(drops) == "table" and drops or {}) do
                if drop == oreId and pickOre:InvokeServer(uuid) then
                    Util.Remote("Stage", "ClaimedAllOreRE"):FireServer()
                    F.OreStage[oreId] = stageId
                    return true
                end
            end
        end
        return false
    end

    local function EnsureOre(oreId, need)
        local profile = GetProfile()
        local uuid = Uuid(profile, oreId)
        if not uuid then
            if not AcquireOre(oreId) then return nil end
            task.wait(0.4)
            profile = GetProfile()
            uuid = Uuid(profile, oreId)
        end
        if uuid and Count(profile, oreId) < need then
            AddOre(uuid, math.max(FC.RefillAmount, need))
            task.wait(0.4)
        end
        return uuid
    end

    local function Anchors(profile)
        local anchors, bestPower = {}, {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.Type == "Weapon" or entry.Type == "Armor" or entry.Type == "Hat" then
                local helper = GameLib.Api(entry.Type == "Weapon" and Cfg().Weapon.Helper or Cfg().Armor.Helper)
                local ok, percent = pcall(helper.CheckIsBestPercent, entry.ID)
                if ok and not percent then
                    local powerOk, power = pcall(helper.GetMainAffix, entry.ID)
                    if powerOk and type(power) == "number" and power > (bestPower[entry.Type] or 0) then
                        bestPower[entry.Type] = power
                        anchors[entry.Type] = uuid
                    end
                end
            end
        end
        local keep = {}
        for _, uuid in pairs(anchors) do keep[uuid] = true end

        local localData = ReplicatedStorage:FindFirstChild("LocalData")
        local backpackModule = localData and localData:FindFirstChild("BackpackData")
        local backpack = backpackModule and GameLib.Require(backpackModule)
        if type(backpack) == "table" and type(backpack.IsLocked) == "function" then
            for uuid in pairs(profile.Backpack.have) do
                local ok, locked = pcall(backpack.IsLocked, uuid)
                if ok and locked then keep[uuid] = true end
            end
        end
        return keep
    end

    local function SellFresh(fresh, keep)
        local profile = F.Profile or GetProfile()
        local protected = Anchors(profile)
        for _, uuid in pairs(profile.Backpack.equiped) do protected[uuid] = true end
        local sell = Util.Remote("Backpack", "TrySellItemRE")
        for uuid in pairs(fresh) do
            if not protected[uuid] and not (keep and keep[uuid]) then
                sell:FireServer(uuid, 1)
            end
        end
    end

    local function GearScore(entry, atTarget)
        local balance = GameLib.Api(ReplicatedStorage.Utils.BalanceUtils)
        local backpack = (F.Profile or GetProfile()).Backpack
        local potential = table.clone(entry)
        if atTarget then potential.Level = math.max(entry.Level or 0, FC.ScoreLevel) end
        local value = entry.Type == "Weapon" and balance.GetWeaponTrainValue or balance.GetArmorValue
        local ok, power = pcall(value, LocalPlayer, potential, backpack)
        if not ok or type(power) ~= "number" then return 0 end
        return power * (1 + (entry.Level or 0) * 1e-6 + #(entry.EnchanceList or {}) * 1e-9)
    end

    local function Target()
        for _, target in ipairs(FC.Targets) do
            if target.name == F.Opt.ForgeTarget then return target end
        end
        return FC.Targets[1]
    end

    local function RunForge(forgeType, oreList)
        return Util.Remote("Forge", "ForgeRF"):InvokeServer({ ConfigType = forgeType, UUIDList = oreList })
    end

    local function PickOwned(profile, count)
        local opt = F.Opt
        local candidates = {}
        for _, ore in ipairs(OwnedOres(profile)) do
            local spare = ore.number - opt.KeepPerOre
            if Ore.Allows(opt.ForgeRarities, ore.rarity) and spare > 0 then
                ore.spare = spare
                table.insert(candidates, ore)
            end
        end
        if not opt.BestOreFirst then
            table.sort(candidates, function(a, b) return a.tier < b.tier end)
        end
        local pick, need = {}, count
        for _, ore in ipairs(candidates) do
            if need <= 0 then break end
            local take = math.min(need, ore.spare)
            pick[ore.uuid] = take
            need -= take
        end
        return need <= 0 and pick or nil
    end

    local function PickOre(count)
        local oreId = F.OreLabels[F.Opt.ForgeOre]
        if not oreId then return PickOwned(GetProfile(), count) end
        local uuid = EnsureOre(oreId, count * F.Opt.ForgePerTick)
        return uuid and { [uuid] = count }
    end

    local function ForgeOnce()
        local target = Target()
        local pick = PickOre(target.ores)
        if not pick then return false end
        local result = RunForge(target.forgeType, pick)
        return result ~= nil and result ~= false
    end

    local function ForgeBurst()
        local target = Target()
        local perTick = F.Opt.ForgePerTick
        local pick = PickOre(target.ores * perTick)
        if not pick then return 0 end
        local completed = 0
        local uuid = next(pick)
        if next(pick, uuid) == nil then
            for _ = 1, perTick do
                if not F.Alive then break end
                local result = RunForge(target.forgeType, { [uuid] = target.ores })
                if result ~= nil and result ~= false then completed += 1 end
            end
            return completed
        end
        for _ = 1, perTick do
            if not F.Alive or not ForgeOnce() then break end
            completed += 1
        end
        return completed
    end

    local function ForgeStep()
        if not F.Opt.SellJunk then return ForgeBurst() end
        local before = Snapshot()
        local completed = ForgeBurst()
        local fresh = NewGear(before)
        local profile = F.Profile
        local keep = {}
        for uuid, entry in pairs(fresh) do
            local worn = profile.Backpack.equiped[entry.Type]
            local wornEntry = worn and profile.Backpack.have[worn]
            if not wornEntry or GearScore(entry, true) > GearScore(wornEntry, true) then
                keep[uuid] = true
            end
        end
        SellFresh(fresh, keep)
        return completed
    end

    local toggleAuto

    local function StartAutoForge()
        if F.Running then return end
        F.Running = true
        task.spawn(function()
            local fails = 0
            while F.Alive and F.Opt.AutoForge do
                if F.Busy then
                    task.wait(FC.TickDelay)
                else
                    F.Busy = true
                    local ok, err = pcall(ForgeStep)
                    F.Busy = false
                    if ok then
                        fails = 0
                        task.wait(FC.TickDelay)
                    else
                        fails += 1
                        if fails == 1 then warn("[LazyJiro] Auto Forge:", tostring(err)) end
                        if fails >= FC.MaxFailures then
                            F.Opt.AutoForge = false
                            if toggleAuto then toggleAuto:Set(false, true) end
                            fnotify("Auto Forge stopped: " .. tostring(err):match("[^\n]*"))
                            break
                        end
                        task.wait(math.min(2, 0.25 * 2 ^ (fails - 1)))
                    end
                end
            end
            F.Running = false

            if F.Alive and F.Opt.AutoForge then StartAutoForge() end
        end)
    end

    local function ForgeNow()
        if F.Busy then return fnotify("Forge is busy, try again in a moment") end
        F.Busy = true
        task.spawn(function()
            local ok, result = pcall(ForgeStep)
            F.Busy = false
            if not ok then
                warn("[LazyJiro] Forge Now:", tostring(result))
                fnotify("Forge failed; check the console")
            elseif (result or 0) > 0 then
                fnotify(("Forged %d time(s)"):format(result))
            else
                fnotify("Nothing forged. Check Forge Ore Rarity and Keep Per Ore")
            end
        end)
    end

    local ForgeCard = ForgeTab:AddCard("Forge", "Left")
    local OreCard = ForgeTab:AddCard("Ore Usage", "Right")

    local targetNames = {}
    for _, target in ipairs(FC.Targets) do table.insert(targetNames, target.name) end
    ForgeCard:AddDropdown({ Name = "Target Gear", Stacked = true, Options = targetNames, Default = targetNames[1], Callback = function(v)
        F.Opt.ForgeTarget = v
    end })

    local oreDropdown = ForgeCard:AddDropdown({
        Name = "Ore To Use", Stacked = true, Description = "Pick an ore and it never runs out",
        Options = { FC.OwnedLabel }, Default = FC.OwnedLabel,
        Callback = function(v) F.Opt.ForgeOre = v end,
    })

    toggleAuto = ForgeCard:AddToggle({ Name = "Auto Forge", Description = "Forges the target gear nonstop", Default = false, Callback = function(v)
        F.Opt.AutoForge = v
        if v then StartAutoForge() end
    end })

    ForgeCard:AddButton({ Name = "Forge Now", Primary = true, Callback = ForgeNow })

    ForgeCard:AddSlider({ Name = "Forges Per Round", Min = 1, Max = 50, Default = 10, Increment = 1, Callback = function(v)
        F.Opt.ForgePerTick = v
    end })

    ForgeCard:AddToggle({ Name = "Sell worse gear right away", Default = false, Callback = function(v)
        F.Opt.SellJunk = v
    end })

    OreCard:AddLabel("Used when Ore To Use is Owned ores")

    OreCard:AddToggle({ Name = "Spend Best Ore First", Description = "Off = spend the weakest ore first", Default = false, Callback = function(v)
        F.Opt.BestOreFirst = v
    end })

    local rarityDropdown = OreCard:AddDropdown({
        Name = "Forge Ore Rarity", Stacked = true, Multi = true,
        Description = "Only these ore rarities are used for forging",
        Options = { "Loading..." }, Default = {},
        Callback = function(set)
            set["Loading..."] = nil
            F.Opt.ForgeRarities = set
        end,
    })

    local keepInput
    keepInput = OreCard:AddInput({
        Name = "Keep Per Ore", Stacked = true, Description = "Never forge below this amount of each ore",
        Default = "0", Placeholder = "0",
        Callback = function(text)
            F.Opt.KeepPerOre = math.max(0, math.floor(tonumber(text) or F.Opt.KeepPerOre))
            if keepInput then keepInput:Set(tostring(F.Opt.KeepPerOre)) end
        end,
    })

    task.spawn(function()
        local ok, labels = pcall(OreChoices)
        if ok and #labels > 0 then
            oreDropdown:Refresh(labels)
            oreDropdown:Set(FC.OwnedLabel, true)
        else
            warn("[LazyJiro] forge ore list:", labels)
            fnotify("Ore list could not be read, only Owned ores will work")
        end
    end)

    task.spawn(function()
        local ok, names = pcall(Shared.RarityNames)
        if ok and type(names) == "table" and #names > 0 then
            rarityDropdown:Refresh(names)
            rarityDropdown:Set(names)
        else
            warn("[LazyJiro] forge rarity list:", names)
            rarityDropdown:Refresh({ "Unavailable" })
            rarityDropdown:Set({}, true)
            fnotify("Rarity list could not be read, so Owned ores can't be filtered")
        end
    end)

    Window.reg({ Disconnect = function() F.Alive = false end })
end

local SellTab = SellPage:AddTab("Sell")
do
    local Util, GameLib, Cfg, notify = Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify
    local Ore = Shared.Ore

    local SC = { Interval = 1, MaxFailures = 5, GearTypes = { "Weapon", "Armor", "Hat" } }

    local S = {
        Alive = true, Busy = false, RunId = 0,
        Opt = {
            AutoSell = false,
            SellTypes = { Weapon = true, Armor = true, Hat = true },
            SellRarities = {},
            KeepPerItem = 1,
        },
    }

    local function snotify(text, title) notify(text, title or "Sell") end

    local function GetProfile()
        return Util.Remote("Profile", "GetTotalDataRF"):InvokeServer()
    end

    local function GearHelper(entryType)
        return GameLib.Api(entryType == "Weapon" and Cfg().Weapon.Helper or Cfg().Armor.Helper)
    end

    local function RarityOf(entry)
        local folder = entry.Type == "Weapon" and "Weapon" or "Armor"
        local itemConfig = GameLib.Need(Cfg()[folder].Config)[entry.ID]
        local rarity = itemConfig and itemConfig.Rarity
        if type(rarity) == "number" then
            local ok, name = pcall(function() return GameLib.Api(Cfg().Rarity.Helper).GetRarityByLevel(rarity) end)
            if ok and name then return name end
        end
        return rarity
    end

    local function Anchors(profile)
        local anchors, bestPower = {}, {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.Type == "Weapon" or entry.Type == "Armor" or entry.Type == "Hat" then
                local helper = GearHelper(entry.Type)
                local ok, percent = pcall(helper.CheckIsBestPercent, entry.ID)
                if ok and not percent then
                    local powerOk, power = pcall(helper.GetMainAffix, entry.ID)
                    if powerOk and type(power) == "number" and power > (bestPower[entry.Type] or 0) then
                        bestPower[entry.Type] = power
                        anchors[entry.Type] = uuid
                    end
                end
            end
        end
        local keep = {}
        for _, uuid in pairs(anchors) do keep[uuid] = true end
        local localData = ReplicatedStorage:FindFirstChild("LocalData")
        local backpackModule = localData and localData:FindFirstChild("BackpackData")
        local backpack = backpackModule and GameLib.Require(backpackModule)
        if type(backpack) == "table" and type(backpack.IsLocked) == "function" then
            for uuid in pairs(profile.Backpack.have) do
                local ok, locked = pcall(backpack.IsLocked, uuid)
                if ok and locked then keep[uuid] = true end
            end
        end
        return keep
    end

    local function SellRun(profile)
        local opt = S.Opt
        local protected = Anchors(profile)
        for _, uuid in pairs(profile.Backpack.equiped) do protected[uuid] = true end

        local byId = {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if opt.SellTypes[entry.Type] and not protected[uuid] then
                byId[entry.ID] = byId[entry.ID] or {}
                table.insert(byId[entry.ID], { uuid = uuid, entry = entry })
            end
        end

        local sell = Util.Remote("Backpack", "TrySellItemRE")
        local sent = 0
        for _, items in pairs(byId) do
            table.sort(items, function(a, b) return (a.entry.Level or 0) > (b.entry.Level or 0) end)
            for index, gear in ipairs(items) do
                if index > opt.KeepPerItem and Ore.Allows(opt.SellRarities, RarityOf(gear.entry)) then
                    sell:FireServer(gear.uuid, 1)
                    sent += 1
                end
            end
        end
        return sent
    end

    local function SellOnce()
        return SellRun(GetProfile())
    end

    local toggleAuto

    local function StartAutoSell()
        S.RunId += 1
        local run = S.RunId
        task.spawn(function()
            local fails = 0
            while S.Alive and S.Opt.AutoSell and S.RunId == run do
                if not S.Busy then
                    S.Busy = true
                    local ok, err = pcall(SellOnce)
                    S.Busy = false
                    if ok then
                        fails = 0
                    else
                        fails += 1
                        if fails == 1 then warn("[LazyJiro] Auto Sell:", tostring(err)) end
                        if fails >= SC.MaxFailures then
                            S.Opt.AutoSell = false
                            if toggleAuto then toggleAuto:Set(false, true) end
                            snotify("Auto Sell stopped: " .. tostring(err):match("[^\n]*"), "Warning")
                            break
                        end
                    end
                end
                task.wait(SC.Interval)
            end
        end)
    end

    local SellCard = SellTab:AddCard("Auto Sell", "Left")
    local FilterCard = SellTab:AddCard("Filters", "Right")

    toggleAuto = SellCard:AddToggle({
        Name = "Auto Sell",
        Description = "Sells gear that matches your filters. Equipped gear is never sold",
        Default = false,
        Callback = function(v)
            S.Opt.AutoSell = v
            if v then StartAutoSell() else S.RunId += 1 end
        end,
    })

    SellCard:AddButton({ Name = "Sell All Now", Primary = true, Callback = function()
        if S.Busy then return snotify("Busy, try again in a moment", "Warning") end
        S.Busy = true
        task.spawn(function()
            local ok, result = pcall(SellOnce)
            S.Busy = false
            if not ok then
                warn("[LazyJiro] Sell All Now:", tostring(result))
                snotify("Sell failed; check the console", "Error")
            else
                snotify(("Sold %d item(s)"):format(result or 0), "Success")
            end
        end)
    end })

    FilterCard:AddDropdown({
        Name = "Sell Item Types", Stacked = true, Multi = true,
        Options = SC.GearTypes, Default = SC.GearTypes,
        Callback = function(set) S.Opt.SellTypes = set end,
    })

    local rarityDropdown = FilterCard:AddDropdown({
        Name = "Sell Rarity Filter", Stacked = true, Multi = true,
        Description = "Only sell these rarities",
        Options = { "Loading..." }, Default = {},
        Callback = function(set)
            set["Loading..."] = nil
            S.Opt.SellRarities = set
        end,
    })

    local keepInput
    keepInput = FilterCard:AddInput({
        Name = "Keep Per Item", Stacked = true,
        Description = "Keeps this many of each item, highest enhance first",
        Default = "1", Placeholder = "1",
        Callback = function(text)
            S.Opt.KeepPerItem = math.max(0, math.floor(tonumber(text) or S.Opt.KeepPerItem))
            if keepInput then keepInput:Set(tostring(S.Opt.KeepPerItem)) end
        end,
    })

    task.spawn(function()
        local ok, names = pcall(Shared.RarityNames)
        if ok and type(names) == "table" and #names > 0 then
            rarityDropdown:Refresh(names)
            rarityDropdown:Set(names)
        else
            warn("[LazyJiro] sell rarity list:", names)
            rarityDropdown:Refresh({ "Unavailable" })
            rarityDropdown:Set({}, true)
            snotify("Rarity list could not be read, so selling can't be filtered", "Warning")
        end
    end)

    Window.reg({ Disconnect = function() S.Alive = false; S.RunId += 1 end })
end

local UpgradeTab = UpgradePage:AddTab("Upgrade")
do
    local Util, GameLib, Cfg, notify = Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify
    local UserInputService = game:GetService("UserInputService")

    local UC = {
        MaxFailures = 5,
        TrainRejoinDelay = 0.3, TrainWatchdog = 3, TrainAcceptWait = 1.5, TrainExitTries = 3, TrainSettle = 0.5,
        RebirthInterval = 2, UpgradeInterval = 5, TrainInterval = 1,
    }

    local U = {
        Alive = true, Loops = {}, Fails = {}, Toggles = {},
        TrainArea = nil, TrainPending = nil, TrainEntering = false, TrainGen = 0, TrainFiredAt = 0,
        TrainRebirth = nil, TrainLevel = nil, TrainNilSince = nil,
        Opt = {
            AutoTrain = false, AutoClick = false, ClickTurbo = true, HyperTrain = false,
            TrainArea = "Auto Best", GuaranteedCrit = false, DamageMultiplier = 5,
            AutoRebirth = false, AutoUpgrade = false, Upgrades = {},
        },
        TrainUUIDs = {}, FetchingTrainUUIDs = false, Clicking = false,
    }

    local function unotify(text, title) notify(text, title or "Upgrade") end

    local function GetProfile()
        return Util.Remote("Profile", "GetTotalDataRF"):InvokeServer()
    end

    local function SelectedArea()
        return tonumber(string.match(tostring(U.Opt.TrainArea or ""), "Area (%d+)"))
    end

    local function FindBestArea(gen)
        local areas = GameLib.Need(Cfg().TrainArea.Config)
        local ids, seen = {}, {}
        for areaId, area in pairs(areas) do
            local id = tonumber(areaId)
            if id and not seen[id] and type(area) == "table" then
                seen[id] = true
                table.insert(ids, { id = id, basic = tonumber(area.Basic) or 0 })
            end
        end
        table.sort(ids, function(a, b)
            if a.basic == b.basic then return a.id > b.id end
            return a.basic > b.basic
        end)

        local function Live()
            return U.Alive and U.Opt.AutoTrain and U.TrainGen == gen
        end

        local into = Util.Remote("Train", "IntoAutoTrainRE")
        for _, entry in ipairs(ids) do
            local areaId = entry.id
            if not Live() then U.TrainPending = nil; return nil end
            U.TrainPending = areaId
            into:FireServer(areaId, true)
            local deadline = os.clock() + UC.TrainAcceptWait
            while Live() and os.clock() < deadline and tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID")) ~= areaId do
                task.wait(0.1)
            end
            if Live() and tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID")) == areaId then
                U.TrainPending = nil
                return areaId
            end
        end
        U.TrainPending = nil
        return nil
    end

    local function TrainEnter()
        if not U.Opt.AutoTrain or U.TrainEntering then return end
        local fixed = SelectedArea()
        if fixed then U.TrainArea = fixed end
        if U.TrainArea then
            if os.clock() - U.TrainFiredAt < UC.TrainAcceptWait then return end
            U.TrainFiredAt = os.clock()
            Util.Remote("Train", "IntoAutoTrainRE"):FireServer(U.TrainArea, true)
            return
        end
        local gen = U.TrainGen
        U.TrainEntering = true
        local ok, areaId = pcall(FindBestArea, gen)
        U.TrainEntering = false
        if not ok then error(areaId, 0) end
        if U.TrainGen == gen and areaId then
            U.TrainArea = areaId
            U.TrainFiredAt = os.clock()
        end
    end

    local function TrainLeave()
        local exit = Util.FindRemote("Train", "ExitAutoTrainRE")
        local into = Util.FindRemote("Train", "IntoAutoTrainRE")
        if not (exit or into) then return end
        for _ = 1, UC.TrainExitTries do
            local areaId = LocalPlayer:GetAttribute("AutoTrainAreaID") or U.TrainPending or U.TrainArea
            if not areaId then return end
            if exit then exit:FireServer(areaId) else into:FireServer(areaId, false) end
            if not U.Alive then
                U.TrainPending = nil
                return
            end
            task.wait(UC.TrainSettle)
            if U.Opt.AutoTrain then return end
            if not LocalPlayer:GetAttribute("AutoTrainAreaID") then
                U.TrainPending = nil
                return
            end
        end
        warn("[LazyJiro] training area still set after", UC.TrainExitTries, "exits")
    end

    local function SetTraining(enabled)
        U.TrainGen += 1
        if enabled then TrainEnter() else TrainLeave() end
    end

    local function UsePotions(profile)
        local potionConfig = GameLib.Need(Cfg().Potion.Config)
        local now = workspace:GetAttribute("ServerTime") or os.time()
        local buffs = profile.Buff or {}
        for potionName, count in pairs(profile.Potion or {}) do
            local buffId = potionConfig[potionName] and potionConfig[potionName].BuffID
            local active = buffId and type(buffs[buffId]) == "number" and buffs[buffId] > now
            if type(count) == "number" and count > 0 and not active then
                Util.Remote("Potion", "TryUsePotionRE"):FireServer(potionName, 1)
            end
        end
    end

    local function TrainStep()
        local profile = GetProfile()
        UsePotions(profile)
        if profile.Eco.rebirth ~= U.TrainRebirth or profile.Eco.level ~= U.TrainLevel then
            U.TrainRebirth = profile.Eco.rebirth
            U.TrainLevel = profile.Eco.level
            U.TrainArea = nil
        end
        local current = tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID"))
        local fixed = SelectedArea()
        if current and fixed and current ~= fixed then
            U.TrainNilSince = nil
            TrainEnter()
            return
        end
        if current then
            U.TrainNilSince = nil
            return
        end
        U.TrainNilSince = U.TrainNilSince or os.clock()
        if os.clock() - U.TrainNilSince < UC.TrainWatchdog then return end
        TrainEnter()
    end

    Window.reg(LocalPlayer:GetAttributeChangedSignal("AutoTrainAreaID"):Connect(function()
        if not U.Opt.AutoTrain or LocalPlayer:GetAttribute("AutoTrainAreaID") then return end
        task.delay(UC.TrainRejoinDelay, function()
            if U.Alive and U.Opt.AutoTrain and not LocalPlayer:GetAttribute("AutoTrainAreaID") then
                Util.Try(TrainEnter)
            end
        end)
    end))

    local function CurrentArea()
        return SelectedArea() or U.TrainArea or tonumber(LocalPlayer:GetAttribute("AutoTrainAreaID")) or 9
    end

    local function RefillTrainUUIDs()
        if U.FetchingTrainUUIDs then return end
        U.FetchingTrainUUIDs = true
        task.spawn(function()
            pcall(function()
                local rf = Util.FindRemote("Train", "InvokTrainDataListRF")
                local encoding = rf and GameLib.Require(ReplicatedStorage.Utils.EncodingUtils)
                if not (rf and encoding) then return end
                for _ = 1, 2 do
                    local ok, raw = pcall(rf.InvokeServer, rf, CurrentArea())
                    local list = ok and raw and encoding.DecodeTable(raw)
                    if type(list) == "table" then
                        for _, item in ipairs(list) do
                            if item.UUID then table.insert(U.TrainUUIDs, item.UUID) end
                        end
                    end
                end
            end)
            U.FetchingTrainUUIDs = false
        end)
    end

    local function PopTrainUUID()
        if #U.TrainUUIDs < 250 then RefillTrainUUIDs() end
        return table.remove(U.TrainUUIDs, 1)
    end

    local function ClickBurst(count)
        count = count or (U.Opt.ClickTurbo and 50 or 15)
        local trainOnce = Util.FindRemote("Train", "TrainOnceRE")
        local into = Util.FindRemote("Train", "IntoAutoTrainRE")
        if into and not LocalPlayer:GetAttribute("AutoTrainAreaID") then
            pcall(into.FireServer, into, CurrentArea(), true)
        end
        if not trainOnce then return end
        for _ = 1, count do
            local uuid = PopTrainUUID()
            if not uuid then break end
            trainOnce:FireServer(uuid)
        end
        LocalPlayer:SetAttribute("LastTrainTick", tick())
    end

    local function StartClicking()
        if U.Clicking then return end
        U.Clicking = true
        task.spawn(function()
            local trainOnce = Util.FindRemote("Train", "TrainOnceRE")
            local into = Util.FindRemote("Train", "IntoAutoTrainRE")
            local lastEnter = 0
            while U.Alive and U.Opt.AutoClick do
                pcall(function()
                    if into and not U.Opt.AutoTrain and not LocalPlayer:GetAttribute("AutoTrainAreaID") and os.clock() - lastEnter > UC.TrainAcceptWait then
                        lastEnter = os.clock()
                        into:FireServer(CurrentArea(), true)
                    end
                    local batch = U.Opt.HyperTrain and 50 or (U.Opt.ClickTurbo and 25 or 10)
                    for _ = 1, batch do
                        local uuid = PopTrainUUID()
                        if not (uuid and trainOnce) then break end
                        trainOnce:FireServer(uuid)
                    end
                    LocalPlayer:SetAttribute("LastTrainTick", tick())
                end)
                task.wait(U.Opt.HyperTrain and 0.01 or (U.Opt.ClickTurbo and 0.02 or 0.08))
            end
            U.Clicking = false
        end)
    end

    local function Rebirth()
        Util.Remote("Rebirth", "TryRebirthRE"):FireServer()
    end

    local function RebirthStep()
        local profile = GetProfile()
        local ok, needLevel = pcall(GameLib.Api(Cfg().Rebirth.Helper).GetNeedLevel, profile.Eco.rebirth + 1)
        if ok and needLevel and profile.Eco.level >= needLevel then
            Rebirth()
        end
    end

    local function UpgradeNames()
        local names = {}
        for name in pairs(GameLib.Need(Cfg().Upgrade.Config)) do
            table.insert(names, name)
        end
        table.sort(names)
        return names
    end

    local function BuySelected()
        local buy = Util.Remote("Upgrade", "UpgradeOnceRE")
        for name, selected in pairs(U.Opt.Upgrades) do
            if selected and name ~= "Loading..." then buy:FireServer(name) end
        end
    end

    local function Run(key, fn)
        if not U.Alive or not U.Opt[key] then return end
        local ok, err = pcall(fn)
        if ok then U.Fails[key] = nil; return end
        local fails = (U.Fails[key] or 0) + 1
        U.Fails[key] = fails
        if fails == 1 then warn("[LazyJiro]", key, tostring(err)) end
        if fails >= UC.MaxFailures then
            U.Fails[key] = nil
            U.Opt[key] = false
            local reason = tostring(err):match("[^\n]*")
            warn("[LazyJiro]", key, "stopped:", reason)
            local toggle = U.Toggles[key]
            if toggle then toggle:Set(false, true) end
            if key == "AutoTrain" then task.spawn(Util.Try, SetTraining, false) end
            unotify(key .. " stopped: " .. reason, "Warning")
            return
        end
        task.wait(math.min(2, 0.25 * 2 ^ (fails - 1)))
    end

    local function StartLoop(key, delay, fn)
        if U.Loops[key] then return end
        U.Loops[key] = true
        task.spawn(function()
            while U.Alive do
                local started = os.clock()
                if U.Opt[key] then Run(key, fn) end
                local period = math.max(0.04, U.Opt[key] and delay() or 0.1)
                local elapsed = os.clock() - started
                task.wait(elapsed < period and math.max(0.001, period - elapsed) or period)
            end
            U.Loops[key] = nil
        end)
    end

    local TrainCard = UpgradeTab:AddCard("Training", "Left", "OP")
    local UpgradeCard = UpgradeTab:AddCard("Upgrades", "Right")

    local RestoreCalc
    local function HookCalc()
        if RestoreCalc then return true end
        local utils = ReplicatedStorage:FindFirstChild("Utils")
        local module = utils and utils:FindFirstChild("CalculateUtils")
        local calc = module and GameLib.Require(module)
        if type(calc) ~= "table" then return false end

        local origCrit, origDamage, origOnce = calc.CCCrit, calc.CCPlrDamage, calc.CCPlrOnceDamage

        if type(origCrit) == "function" then
            calc.CCCrit = function(player, ...)
                if player == LocalPlayer and U.Opt.GuaranteedCrit then return 1.0 end
                return origCrit(player, ...)
            end
        end
        if type(origDamage) == "function" then
            calc.CCPlrDamage = function(player, ...)
                local dmg = origDamage(player, ...)
                local mult = U.Opt.DamageMultiplier
                if player == LocalPlayer and type(dmg) == "number" and mult and mult > 1 then return dmg * mult end
                return dmg
            end
        end
        if type(origOnce) == "function" then
            calc.CCPlrOnceDamage = function(player, ...)
                local dmg = origOnce(player, ...)
                local mult = U.Opt.DamageMultiplier
                if player == LocalPlayer and type(dmg) == "number" and mult and mult > 1 then return dmg * mult end
                return dmg
            end
        end

        RestoreCalc = function()
            if type(origCrit) == "function" then calc.CCCrit = origCrit end
            if type(origDamage) == "function" then calc.CCPlrDamage = origDamage end
            if type(origOnce) == "function" then calc.CCPlrOnceDamage = origOnce end
            RestoreCalc = nil
        end
        return true
    end

    local function UnhookCalc()
        if RestoreCalc then RestoreCalc() end
    end

    local function AddCheck(card, spec)
        if card.AddCheckbox then
            local ok, obj = pcall(card.AddCheckbox, card, spec)
            if ok and obj then return obj end
        end
        return card:AddToggle(spec)
    end

    U.Toggles.AutoTrain = TrainCard:AddToggle({
        Name = "Auto Train", Description = "Trains at selected or best area nonstop and uses potions", Default = false,
        Callback = function(v)
            U.Opt.AutoTrain = v
            U.Fails.AutoTrain = nil
            if v then StartLoop("AutoTrain", function() return UC.TrainInterval end, TrainStep) end
            task.spawn(Util.Try, SetTraining, v)
        end,
    })

    TrainCard:AddDropdown({
        Name = "Train Area", Stacked = true,
        Options = {
            "Auto Best",
            "Area 9 (x100 Throne)",
            "Area 8 (25x)",
            "Area 7 (15x)",
            "Area 6 (10x)",
            "Area 5 (8x)",
            "Area 4 (6x)",
            "Area 3 (4x)",
            "Area 2 (2x)",
            "Area 1 (1.5x)",
        },
        Default = "Auto Best",
        Callback = function(v)
            U.Opt.TrainArea = v
            U.TrainArea = nil
            U.TrainFiredAt = 0
            table.clear(U.TrainUUIDs)
            if U.Opt.AutoTrain then task.spawn(Util.Try, TrainEnter) end
        end,
    })

    U.Toggles.AutoClick = TrainCard:AddToggle({
        Name = "Auto Click", Description = "Clicks to train with maximum burst speed", Default = false,
        Callback = function(v)
            U.Opt.AutoClick = v
            U.Fails.AutoClick = nil
            if not v then return end
            if not Util.FindRemote("Train", "TrainOnceRE") then
                U.Opt.AutoClick = false
                U.Toggles.AutoClick:Set(false, true)
                unotify("Auto Click is not available (TrainOnceRE not found)", "Warning")
                return
            end
            StartClicking()
        end,
    })

    AddCheck(TrainCard, { Name = "Turbo Training Burst (20x)", Default = true, Callback = function(v)
        U.Opt.ClickTurbo = v
    end })

    AddCheck(TrainCard, { Name = "Hyper-Speed Mode (50x Stream)", Default = false, Callback = function(v)
        U.Opt.HyperTrain = v
    end })

    U.Toggles.AutoRebirth = AddCheck(TrainCard, {
        Name = "Auto Rebirth When Ready", Default = false,
        Callback = function(v)
            U.Opt.AutoRebirth = v
            U.Fails.AutoRebirth = nil
            if v then StartLoop("AutoRebirth", function() return UC.RebirthInterval end, RebirthStep) end
        end,
    })

    TrainCard:AddButton({ Name = "Train Click Now", Primary = true, Callback = function()
        task.spawn(Util.Try, ClickBurst, 20)
    end })

    TrainCard:AddButton({ Name = "Rebirth Now", Primary = false, Callback = function()
        task.spawn(function()
            local ok, err = pcall(Rebirth)
            if not ok then
                warn("[LazyJiro] rebirth:", tostring(err))
                unotify("Rebirth failed; check the console", "Error")
            else
                unotify("Rebirth sent")
            end
        end)
    end })

    U.Toggles.GuaranteedCrit = TrainCard:AddToggle({
        Name = "Guaranteed Crit (100%)", Description = "Guarantees critical hits on every attack and training hit", Default = false,
        Callback = function(v)
            U.Opt.GuaranteedCrit = v
            if v then
                if not HookCalc() then
                    U.Opt.GuaranteedCrit = false
                    U.Toggles.GuaranteedCrit:Set(false, true)
                    unotify("Guaranteed Crit is not available on this executor", "Warning")
                end
            elseif not (U.Opt.DamageMultiplier and U.Opt.DamageMultiplier > 1) then
                UnhookCalc()
            end
        end,
    })

    TrainCard:AddSlider({ Name = "Damage Multiplier", Min = 1, Max = 20, Default = 5, Increment = 1, Suffix = "x", Callback = function(v)
        U.Opt.DamageMultiplier = tonumber(v) or 5
        if U.Opt.DamageMultiplier > 1 then
            if not HookCalc() then unotify("Damage Multiplier is not available on this executor", "Warning") end
        elseif not U.Opt.GuaranteedCrit then
            UnhookCalc()
        end
    end })

    local upgradeDropdown = UpgradeCard:AddDropdown({
        Name = "Upgrades To Buy", Stacked = true, Multi = true,
        Options = { "Loading..." }, Default = {},
        Callback = function(set)
            set["Loading..."] = nil
            U.Opt.Upgrades = set
        end,
    })

    U.Toggles.AutoUpgrade = UpgradeCard:AddToggle({
        Name = "Auto Buy Upgrades", Description = "Buys the selected upgrades whenever possible", Default = false,
        Callback = function(v)
            U.Opt.AutoUpgrade = v
            U.Fails.AutoUpgrade = nil
            if v then StartLoop("AutoUpgrade", function() return UC.UpgradeInterval end, BuySelected) end
        end,
    })

    UpgradeCard:AddButton({ Name = "Buy Upgrade Now", Primary = false, Callback = function()
        task.spawn(function()
            local ok, err = pcall(BuySelected)
            if not ok then
                warn("[LazyJiro] buy upgrade:", tostring(err))
                unotify("Buy failed; check the console", "Error")
            else
                unotify("Upgrade purchase sent")
            end
        end)
    end })

    task.spawn(function()
        local ok, names = pcall(UpgradeNames)
        if ok and type(names) == "table" and #names > 0 then
            upgradeDropdown:Refresh(names)
            upgradeDropdown:Set(names)
        else
            warn("[LazyJiro] upgrade list:", names)
            upgradeDropdown:Refresh({ "Unavailable" })
            upgradeDropdown:Set({}, true)
            unotify("Upgrade list could not be read", "Warning")
        end
    end)

    Window.reg({ Disconnect = function()
        U.Alive = false
        UnhookCalc()
        if U.Opt.AutoTrain then
            U.Opt.AutoTrain = false
            task.spawn(Util.Try, TrainLeave)
        end
    end })
end

local PetEggTab = ForgePage:AddTab("Pet and Egg")
do
    local Util, GameLib, Cfg, notify = Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify

    local PS = {
        Alive = true, Busy = nil, Profile = nil, ProfileTime = 0, TargetLabels = {}, RarityLv = {},
        Opt = {
            SkipEggAnim = true, Protected = { Legendary = true, Mythic = true, Eternal = true },
            KeepPerEgg = 10, KeepBestPets = 6, AutoLockTargetPet = true, HatchBestFirst = true, TargetPet = nil,
        },
    }

    local function pnotify(text) notify(text, "Pets & Eggs") end

    local function R(folder, name)
        local root = ReplicatedStorage:FindFirstChild("Remote")
        local holder = root and (root:FindFirstChild(folder .. "_Server") or root:FindFirstChild(folder))
        local direct = holder and holder:FindFirstChild(name)
        return direct or Util.Remote(folder, name)
    end

    local function FR(folder, name)
        local root = ReplicatedStorage:FindFirstChild("Remote")
        local holder = root and (root:FindFirstChild(folder .. "_Server") or root:FindFirstChild(folder))
        local direct = holder and holder:FindFirstChild(name)
        return direct or Util.FindRemote(folder, name)
    end

    local function GetProfile(force)
        local now = os.clock()
        if not force and PS.Profile and now - PS.ProfileTime < 0.35 then return PS.Profile end
        local ok, profile = pcall(function() return R("Profile", "GetTotalDataRF"):InvokeServer() end)
        if ok and type(profile) == "table" then
            PS.Profile, PS.ProfileTime = profile, now
            return profile
        end
        if PS.Profile then return PS.Profile end
        error("profile unavailable; retry after loading", 0)
    end

    local function ToSet(set)
        local out = {}
        for key, value in pairs(set or {}) do
            if type(key) == "number" then out[value] = true elseif value then out[key] = true end
        end
        return out
    end

    local function ServerNow()
        return (workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or (workspace:GetAttribute("ServerTime") or os.time())
    end

    local function RarityLevel(rarity)
        if rarity == nil then return 0 end
        local cached = PS.RarityLv[rarity]
        if cached then return cached end
        local ok, level = pcall(function() return GameLib.Api(Cfg().Rarity.Helper).GetRarityLevel(rarity) end)
        level = ok and tonumber(level) or 0
        PS.RarityLv[rarity] = level
        return level
    end

    local function Parallel(workers, job)
        local pending, failure = workers, nil
        for _ = 1, workers do
            task.spawn(function()
                local ok, err = pcall(job)
                if not ok then failure = failure or err end
                pending -= 1
            end)
        end
        local deadline = os.clock() + 20
        while PS.Alive and pending > 0 and os.clock() < deadline do task.wait(0.05) end
        if failure then error(failure, 0) end
    end

    local function EquippedSet(petStore)
        local set = {}
        for _, uuid in pairs(petStore.equiped or {}) do set[uuid] = true end
        return set
    end

    -- Season coins and tower (used by the Event pet draws and rainbow crafts)
    local function SeasonCurrent(profile)
        local seasons = (profile or GetProfile()).Season or {}
        local active = workspace:GetAttribute("Season")
        if active and type(seasons[active]) == "table" then return seasons[active] end
        if type(seasons.Season2) == "table" then return seasons.Season2 end
        if type(seasons.Season1) == "table" then return seasons.Season1 end
        if seasons.Coin or seasons.SeasonCoin then return seasons end
        local bestKey, bestTier = nil, -1
        for key in pairs(seasons) do
            local tier = Util.Tier(key)
            if tier > bestTier then bestKey, bestTier = key, tier end
        end
        return bestKey and seasons[bestKey] or seasons
    end

    local function SeasonCoins(force)
        local season = SeasonCurrent(force and GetProfile(true) or nil)
        return type(season) == "table" and (season.Coin or season.SeasonCoin or 0) or 0
    end

    local function FarmCoins(target)
        target = math.clamp(target or 10000, 100, 1000000)
        local startCoin = SeasonCoins(true)
        local rounds = math.clamp(math.ceil(target / 8000), 1, 100)
        pcall(function() R("Dungeon", "TryIntoDungeonRF"):InvokeServer(true, 50) end)
        local startRE = R("Dungeon", "StartRoundRE")
        local completeRF = R("Dungeon", "CompleteRoundRF")
        for round = 1, rounds do
            if not PS.Alive then break end
            pcall(startRE.FireServer, startRE, 50)
            task.wait(0.04)
            pcall(completeRF.InvokeServer, completeRF, 50)
            if round % 3 == 0 and SeasonCoins(true) - startCoin >= target then break end
        end
        if not State.Running then
            pcall(function() R("Dungeon", "TryIntoDungeonRF"):InvokeServer(false) end)
        end
        return math.max(0, SeasonCoins(true) - startCoin)
    end

    -- Pet data helpers
    local function PetStoreOf(refresh)
        local profile = GetProfile(refresh)
        return profile and profile.Pet or {}
    end

    local function PetRarity(petId)
        local cfg = GameLib.Need(Cfg().Pet.Config)[petId]
        return cfg and cfg.Rarity
    end

    local function PetScore(entry, focus)
        if type(entry) ~= "table" or entry.Type ~= "Pet" then return -1 end
        local cfg = GameLib.Need(Cfg().Pet.Config)[entry.ID]
        if not cfg then return 0 end
        local rarityLv = RarityLevel(cfg.Rarity)
        local gradeMulti = ({ Common = 1, Golden = 2, Diamond = 4, Rainbow = 6 })[entry.Grade] or 1
        local boostSum, trainBoost = 0, 0
        local ok, boosts = pcall(function()
            return GameLib.Api(ReplicatedStorage.Utils.BalanceUtils).GetPetBoosts(LocalPlayer, entry)
        end)
        if ok and type(boosts) == "table" then
            trainBoost = boosts.Train or 0
            for _, val in pairs(boosts) do
                if type(val) == "number" then boostSum += val end
            end
        end
        if focus == "Train" then
            return trainBoost * 100000 + gradeMulti * 1000 + (entry.Level or 1) * 10
        end
        local skills = type(entry.ExtraSkill) == "table" and #entry.ExtraSkill or 0
        return rarityLv * 10000 + boostSum * gradeMulti * 1000 + (entry.Level or 1) * 10 + skills * 500 + Util.Tier(entry.ID)
    end

    local function ResetVFX()
        pcall(function()
            local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local openGui = gui and gui:FindFirstChild("OpenEggGui")
            if openGui and openGui.Enabled then
                local guiUtils = ReplicatedStorage:FindFirstChild("GuiUtils")
                local petGui = guiUtils and guiUtils:FindFirstChild("PetGUI")
                local vfx = petGui and petGui:FindFirstChild("OpenEggVFX")
                if vfx then GameLib.Api(vfx).Reset() end
            end
        end)
    end

    local function MuteAnim(muted)
        if type(getconnections) == "function" then
            pcall(function()
                local remote = FR("Pet", "ShowLuckResult")
                if remote and remote:IsA("RemoteEvent") then
                    for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                        if muted then conn:Disable() else conn:Enable() end
                    end
                end
            end)
        end
        if muted then ResetVFX() end
    end

    local function CountsOf(petStore)
        petStore = petStore or PetStoreOf()
        local pets, eggs = 0, 0
        for _, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" then
                pets += 1
            elseif entry.Type == "Egg" and not entry.HatchReadyTick then
                eggs += 1
            end
        end
        return pets, eggs
    end

    local function TrimEggs(preferEggId)
        local petStore = PetStoreOf()
        local byId, totalEggs = {}, 0
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Egg" and not entry.HatchReadyTick then
                byId[entry.ID] = byId[entry.ID] or {}
                table.insert(byId[entry.ID], uuid)
                totalEggs += 1
            end
        end
        local deleteRE = R("Pet", "DeleteRE")
        local deleted = 0
        local keepLimit = math.max(1, PS.Opt.KeepPerEgg or 10)
        local maxEggs = petStore.maxEggNum or 25
        for eggId, list in pairs(byId) do
            local limit = keepLimit
            if preferEggId and eggId ~= preferEggId and totalEggs >= maxEggs - 3 then
                limit = math.min(limit, math.max(2, math.floor(maxEggs / 4)))
            end
            for i = limit + 1, #list do
                deleteRE:FireServer(list[i])
                deleted += 1
                totalEggs -= 1
            end
        end
        if deleted > 0 then GetProfile(true) end
        return deleted
    end

    -- Stage farming for eggs and fruits
    local function DropInfo(drop)
        local id = type(drop) == "table" and drop.ID or drop
        local dtype = type(drop) == "table" and drop.Type
        if not dtype then
            dtype = type(id) == "string" and (id:find("^Egg") and "Egg" or (id:find("^Food") and "Food")) or "Ore"
        end
        return id, dtype
    end

    local function FarmEggsAndFood(rounds)
        rounds = math.clamp(rounds or 25, 1, 100)
        local finished = R("Stage", "StageFinishedRF")
        local getOre = R("Stage", "GetOreRF")
        local pickStone = R("Stage", "GetEnhantStoneRE")
        local claimAll = R("Stage", "ClaimedAllOreRE")
        local eggs, foods = 0, 0
        TrimEggs("Egg2")
        Parallel(24, function()
            for _ = 1, rounds do
                if not PS.Alive then break end
                local drops = finished:InvokeServer("Stage_27")
                if type(drops) == "table" then
                    for uuid, drop in pairs(drops) do
                        local _, dtype = DropInfo(drop)
                        if dtype == "Material" then
                            pickStone:FireServer(uuid)
                        elseif dtype == "Egg" then
                            if getOre:InvokeServer(uuid, true) then eggs += 1 end
                        elseif dtype == "Food" then
                            if getOre:InvokeServer(uuid, true) then foods += 1 end
                        end
                    end
                end
            end
        end)
        claimAll:FireServer()
        GetProfile(true)
        return eggs, foods
    end

    local function FarmTargetEggs(eggId, needed)
        needed = math.clamp(math.floor(needed or 1), 1, 1000)
        local stageId = eggId == "Egg1" and "Stage_11" or "Stage_27"
        local finished = R("Stage", "StageFinishedRF")
        local getOre = R("Stage", "GetOreRF")
        local pickStone = R("Stage", "GetEnhantStoneRE")
        local claimAll = R("Stage", "ClaimedAllOreRE")
        local got = 0
        local wasFight = LocalPlayer:GetAttribute("IntoFight")
        if wasFight ~= "Stage" then LocalPlayer:SetAttribute("IntoFight", "Stage") end
        TrimEggs(eggId)
        local deadline = os.clock() + 12
        Parallel(16, function()
            while PS.Alive and got < needed and os.clock() < deadline do
                local drops = finished:InvokeServer(stageId)
                if type(drops) ~= "table" then break end
                for uuid, drop in pairs(drops) do
                    if got >= needed then break end
                    local id, dtype = DropInfo(drop)
                    if dtype == "Material" then
                        pickStone:FireServer(uuid)
                    elseif id == eggId then
                        if getOre:InvokeServer(uuid, true) ~= false then got += 1 end
                    end
                end
            end
        end)
        claimAll:FireServer()
        if wasFight ~= "Stage" then LocalPlayer:SetAttribute("IntoFight", wasFight) end
        GetProfile(true)
        return got
    end

    -- Pets
    local function CleanBag(trimEggs)
        local petStore = PetStoreOf()
        local protected = EquippedSet(petStore)
        local allPets = {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" then
                if entry.DeployStartTick or entry.Lock or entry.Locked then protected[uuid] = true end
                table.insert(allPets, { uuid = uuid, entry = entry, score = PetScore(entry) })
            end
        end
        table.sort(allPets, function(a, b) return a.score > b.score end)
        for i = 1, math.min(#allPets, math.max(1, PS.Opt.KeepBestPets or 6)) do
            protected[allPets[i].uuid] = true
        end
        local deleteRE = R("Pet", "DeleteRE")
        local deletedPets = 0
        for _, item in ipairs(allPets) do
            local rarity = PetRarity(item.entry.ID)
            if not protected[item.uuid] and not PS.Opt.Protected[rarity] then
                deleteRE:FireServer(item.uuid)
                deletedPets += 1
            end
        end
        local deletedEggs = trimEggs and TrimEggs() or 0
        if deletedPets > 0 then GetProfile(true) end
        return deletedPets, deletedEggs
    end

    local function TargetEggFor(petId)
        local eggCfg = GameLib.Need(Cfg().Egg.Config)
        for eggId, data in pairs(eggCfg or {}) do
            if type(data) == "table" and data.Loot and data.Loot[petId] then return eggId end
        end
        return "Egg2"
    end

    local function EquipBest(focus)
        local petStore = PetStoreOf()
        local owned = {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" then
                table.insert(owned, { uuid = uuid, score = PetScore(entry, focus) })
            end
        end
        if #owned == 0 then return 0 end
        table.sort(owned, function(a, b) return a.score > b.score end)

        local maxEquip = petStore.maxEquipNum or 1
        local wanted, wantedList = {}, {}
        for i = 1, math.min(maxEquip, #owned) do
            wanted[owned[i].uuid] = owned[i].score
            table.insert(wantedList, owned[i])
        end
        local currentSet = EquippedSet(petStore)
        local equipRE = R("Pet", "IsEquipPetRE")
        local changed = 0
        for uuid in pairs(table.clone(currentSet)) do
            if not wanted[uuid] then
                local entry = petStore.have and petStore.have[uuid]
                local curScore = entry and PetScore(entry, focus) or -1
                local best = wantedList[1]
                if best and best.score > curScore then
                    equipRE:FireServer(uuid, false)
                    currentSet[uuid] = nil
                end
            end
        end
        for _, item in ipairs(wantedList) do
            if not currentSet[item.uuid] then
                equipRE:FireServer(item.uuid, true)
                changed += 1
            end
        end
        if changed > 0 then GetProfile(true) end
        return changed
    end

    local function FeedBest()
        local profile = GetProfile()
        local petStore = profile.Pet or {}
        local foodCfg = GameLib.Need(Cfg().Food.Config)
        local petHelper = GameLib.Api(Cfg().Pet.Helper)
        local foods = {}
        for uuid, entry in pairs(profile.Backpack.have or {}) do
            local count = math.floor(entry.Number or 0)
            local info = entry.Type == "Food" and foodCfg[entry.ID]
            if info and count >= 1 and (info.Exp or 0) > 0 then
                table.insert(foods, { uuid = uuid, count = count, exp = info.Exp })
            end
        end
        if #foods == 0 then return 0 end
        table.sort(foods, function(a, b) return a.exp > b.exp end)

        local equipped = EquippedSet(petStore)
        local targets = {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" and not petHelper.CheckLevelIsMax(entry.Level or 1, entry.ID) then
                local priority = (equipped[uuid] and 1e9 or 0) + (entry.DeployStartTick and 1e8 or 0) + PetScore(entry)
                table.insert(targets, { uuid = uuid, entry = entry, priority = priority })
            end
        end
        if #targets == 0 then return 0 end
        table.sort(targets, function(a, b) return a.priority > b.priority end)

        local target = targets[1]
        local maxLv = petHelper.GetMaxLevel(target.entry.ID) or 20
        local needExp = -(target.entry.Exp or 0)
        for lv = (target.entry.Level or 1) + 1, maxLv do
            needExp += (petHelper.GetNeedExp(lv) or 0)
        end
        if needExp <= 0 then return 0 end

        local feedMap, used = {}, false
        for _, food in ipairs(foods) do
            if needExp <= 0 then break end
            local use = math.min(food.count, math.max(1, math.ceil(needExp / food.exp)))
            if use > 0 then
                feedMap[food.uuid] = use
                needExp -= use * food.exp
                used = true
            end
        end
        if not used then return 0 end
        R("Pet", "FeedPetRE"):FireServer(target.uuid, feedMap)
        GetProfile(true)
        return 1
    end

    local function FeedAllMax()
        local total = 0
        for _ = 1, 15 do
            local fed = FeedBest()
            if fed <= 0 then break end
            total += fed
            task.wait(0.05)
        end
        return total
    end

    local function HatchStep()
        if PS.Opt.SkipEggAnim then MuteAnim(true) end
        local petStore = PetStoreOf()
        local now = ServerNow()
        local petCount = CountsOf(petStore)
        local maxPet = petStore.maxPetNum or 25

        if petCount >= maxPet - 2 then
            CleanBag(false)
            petStore = PetStoreOf(true)
            petCount = CountsOf(petStore)
        end

        local openRE = R("Pet", "TryOpenEggRE")
        local hatchRE = R("Pet", "TryHatchEggRE")
        local opened = 0
        for _, uuid in pairs(petStore.hatched or {}) do
            local entry = petStore.have and petStore.have[uuid]
            if entry and (entry.HatchReadyTick or 0) <= now and petCount + opened < maxPet then
                openRE:FireServer(uuid)
                opened += 1
            end
        end
        if opened > 0 then
            ResetVFX()
            petStore = PetStoreOf(true)
        end

        local usedSlots = 0
        for _ in pairs(petStore.hatched or {}) do usedSlots += 1 end
        local freeSlots = math.max(0, (petStore.maxHatchNum or 3) - usedSlots)
        local hatched = 0
        if freeSlots > 0 then
            local targetEggId = "Egg2"
            local pickedPet = PS.Opt.TargetPet and PS.TargetLabels[PS.Opt.TargetPet]
            if pickedPet then targetEggId = TargetEggFor(pickedPet) end

            local candidates = {}
            for uuid, entry in pairs(petStore.have or {}) do
                if entry.Type == "Egg" and not entry.HatchReadyTick then
                    table.insert(candidates, { uuid = uuid, isTarget = entry.ID == targetEggId, tier = Util.Tier(entry.ID) })
                end
            end
            table.sort(candidates, function(a, b)
                if a.isTarget ~= b.isTarget then return a.isTarget end
                if PS.Opt.HatchBestFirst then return a.tier > b.tier end
                return a.tier < b.tier
            end)
            for i = 1, math.min(freeSlots, #candidates) do
                hatchRE:FireServer(candidates[i].uuid)
                hatched += 1
            end
        end
        if hatched > 0 or opened > 0 then
            GetProfile(true)
            ResetVFX()
        end
        return opened, hatched
    end

    local function DeployStep()
        local petStore = PetStoreOf()
        local claimed = false
        if type(petStore.deployRewardList) == "table" and next(petStore.deployRewardList) ~= nil then
            R("Pet", "ClaimAllDeployRewardRE"):FireServer()
            claimed = true
        end
        local deployedCount, candidates = 0, {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" then
                if entry.DeployStartTick then
                    deployedCount += 1
                else
                    table.insert(candidates, { uuid = uuid, score = PetScore(entry) })
                end
            end
        end
        local freeSlots = (petStore.maxDeployNum or 2) - deployedCount
        local deployed = 0
        if freeSlots > 0 and #candidates > 0 then
            table.sort(candidates, function(a, b) return a.score > b.score end)
            local deployRE = R("Pet", "IsDeployPetRE")
            for i = 1, math.min(freeSlots, #candidates) do
                deployRE:FireServer(candidates[i].uuid, true)
                deployed += 1
            end
        end
        if deployed > 0 or claimed then GetProfile(true) end
        return claimed, deployed
    end

    local function LockAllHighTier()
        local petStore = PetStoreOf(true)
        local lockRE = R("Pet", "SetUUIDLockRE")
        local equipped = EquippedSet(petStore)
        local locked = 0
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Pet" and not (entry.Lock or entry.Locked) then
                if RarityLevel(PetRarity(entry.ID)) >= 4 or equipped[uuid] then
                    lockRE:FireServer(uuid)
                    locked += 1
                end
            end
        end
        return locked
    end

    local function GradeUpAll()
        local gradeLevel = { Common = 0, Golden = 1, Diamond = 2, Rainbow = 3 }
        local upgradeRF = FR("Pet", "TryUpGradePetRF")
        if not upgradeRF then return 0 end
        local unlockRE = R("Pet", "SetUUIDLockRE")
        local petStore = PetStoreOf(true)
        local equipped = EquippedSet(petStore)
        local upgraded = 0
        for _, target in ipairs({ { "Golden", 1 }, { "Diamond", 2 }, { "Rainbow", 3 } }) do
            petStore = PetStoreOf(true)
            local byId = {}
            for uuid, entry in pairs(petStore.have or {}) do
                if entry.Type == "Pet" and not equipped[uuid] and (gradeLevel[entry.Grade or "Common"] or 0) == target[2] - 1 then
                    byId[entry.ID] = byId[entry.ID] or {}
                    table.insert(byId[entry.ID], uuid)
                end
            end
            for _, uuids in pairs(byId) do
                while #uuids >= 5 do
                    local batch = {}
                    for i = 1, 5 do
                        local u = uuids[i]
                        batch[u] = true
                        local item = petStore.have and petStore.have[u]
                        if item and (item.Lock or item.Locked) then unlockRE:FireServer(u) end
                    end
                    local ok, res = pcall(function() return upgradeRF:InvokeServer(batch, target[1]) end)
                    if ok and res == true then upgraded += 1 end
                    for _ = 1, 5 do table.remove(uuids, 1) end
                    task.wait(0.04)
                end
            end
        end
        if upgraded > 0 then
            GetProfile(true)
            EquipBest()
            FeedAllMax()
        end
        return upgraded
    end

    local function EventDraw(count, onPet)
        local rf = R("Season", "LuckPetRF")
        local deleteRE = R("Pet", "DeleteRE")
        local lockRE = R("Pet", "SetUUIDLockRE")
        local equipRE = R("Pet", "IsEquipPetRE")
        for _ = 1, count do
            if not PS.Alive then break end
            local store = PetStoreOf(true)
            local slots = 0
            for _, it in pairs(store.have or {}) do
                if it.Type == "Pet" or it.Type == "Egg" then slots += 1 end
            end
            if slots >= 21 then
                local equipped = EquippedSet(store)
                for u, it in pairs(store.have or {}) do
                    if not (it.Lock or it.Locked) and not equipped[u] then
                        if it.Type == "Egg" or it.ID == "Event1_1" or it.ID == "Event1_2" then deleteRE:FireServer(u) end
                    end
                end
                task.wait(0.2)
            end
            local ok, petId = pcall(function() return rf:InvokeServer() end)
            if ok and petId and onPet then onPet(petId, lockRE, equipRE) end
            task.wait(0.02)
        end
    end

    local function FarmAndHatchTarget(petId, needed)
        needed = math.max(1, math.floor(needed or 1))
        if petId:find("^Event1") then
            local acquired = 0
            local deadline = os.clock() + 30
            while PS.Alive and acquired < needed and os.clock() < deadline do
                if SeasonCoins(true) < 400 then FarmCoins(2000) end
                EventDraw(1, function(drawn, lockRE, equipRE)
                    if petId == "Event1" or drawn == petId then acquired += 1 end
                    if drawn == "Event1_4" or drawn == petId then
                        task.wait(0.2)
                        for u, it in pairs(PetStoreOf(true).have or {}) do
                            if it.ID == drawn and not (it.Lock or it.Locked) then
                                lockRE:FireServer(u)
                                if drawn == "Event1_4" then equipRE:FireServer(u, true) end
                            end
                        end
                    end
                end)
            end
            EquipBest()
            FeedAllMax()
            return acquired, acquired > 0 and ("Acquired %d %s from the season draw"):format(acquired, petId) or "Season draw timed out"
        end

        local eggId = TargetEggFor(petId)
        local store = PetStoreOf(true)
        local eggCount = 0
        for _, entry in pairs(store.have or {}) do
            if entry.Type == "Egg" and entry.ID == eggId and not entry.HatchReadyTick then eggCount += 1 end
        end
        if eggCount < 5 then FarmTargetEggs(eggId, 15) end
        HatchStep()

        store = PetStoreOf(true)
        local minLeft = math.huge
        for _, u in pairs(store.hatched or {}) do
            local it = store.have and store.have[u]
            if it and it.HatchReadyTick then minLeft = math.min(minLeft, math.max(0, it.HatchReadyTick - ServerNow())) end
        end
        local gained = 0
        for uuid, entry in pairs(store.have or {}) do
            if entry.Type == "Pet" and entry.ID == petId then
                gained += 1
                if PS.Opt.AutoLockTargetPet and not (entry.Lock or entry.Locked) then
                    R("Pet", "SetUUIDLockRE"):FireServer(uuid)
                end
            end
        end
        if gained > 0 then
            EquipBest()
            FeedAllMax()
            return gained, ("Acquired %s!"):format(petId)
        end
        if minLeft < math.huge then return 0, ("Incubating %s (%ds left)"):format(eggId, minLeft) end
        return 0, "No eggs incubating"
    end

    local function RainbowStep()
        if SeasonCoins(true) < 1600 then FarmCoins(3000) end
        local rf = R("Season", "LuckPetRF")
        for _ = 1, 6 do
            pcall(function() return rf:InvokeServer() end)
            task.wait(0.015)
        end
        GradeUpAll()
        EquipBest()
        FeedAllMax()
    end

    local function CraftRainbow(targetPetId)
        for _, p in pairs(PetStoreOf(true).have or {}) do
            if p.Type == "Pet" and p.Grade == "Rainbow" and (targetPetId == "Any" or p.ID == targetPetId) then
                EquipBest()
                FeedAllMax()
                return true, "Already own Rainbow " .. tostring(p.ID)
            end
        end
        local created = false
        local deadline = os.clock() + 45
        while PS.Alive and os.clock() < deadline and not created do
            if SeasonCoins(true) < 2000 then FarmCoins(4000) end
            EventDraw(10, function(drawn, lockRE, equipRE)
                if drawn == "Event1_4" then
                    task.wait(0.15)
                    for u, it in pairs(PetStoreOf(true).have or {}) do
                        if it.ID == "Event1_4" and not (it.Lock or it.Locked) then
                            lockRE:FireServer(u)
                            equipRE:FireServer(u, true)
                        end
                    end
                end
            end)
            GradeUpAll()
            for _, p in pairs(PetStoreOf(true).have or {}) do
                if p.Type == "Pet" and p.Grade == "Rainbow" and (targetPetId == "Any" or p.ID == targetPetId) then
                    created = true
                    targetPetId = p.ID
                    break
                end
            end
        end
        EquipBest()
        FeedAllMax()
        return created, created and ("Crafted Rainbow %s!"):format(tostring(targetPetId)) or "Fusing in progress, press again to continue"
    end

    local function FindPetByName(part, fallback)
        local folder = Cfg():FindFirstChild("Pet")
        local showModule = folder and folder:FindFirstChild("Show")
        local show = showModule and GameLib.Require(showModule)
        local bestId
        for id, info in pairs(show or {}) do
            local name = tostring(type(info) == "table" and (info.DisplayName or info.Name) or ""):lower()
            if name:find(part, 1, true) and (not bestId or Util.Tier(id) > Util.Tier(bestId)) then bestId = id end
        end
        return bestId or fallback
    end

    local function PetChoices()
        local labels, ids = {}, {}
        local folder = Cfg():FindFirstChild("Pet")
        local showModule = folder and folder:FindFirstChild("Show")
        local cfgModule = folder and folder:FindFirstChild("Config")
        local petShow = showModule and GameLib.Require(showModule)
        local petCfg = cfgModule and GameLib.Require(cfgModule)
        local keys = {}
        for id in pairs(petShow or {}) do keys[id] = true end
        for id in pairs(petCfg or {}) do keys[id] = true end
        local list = {}
        for id in pairs(keys) do list[#list + 1] = id end
        table.sort(list, function(a, b)
            local la = RarityLevel(petCfg and petCfg[a] and petCfg[a].Rarity)
            local lb = RarityLevel(petCfg and petCfg[b] and petCfg[b].Rarity)
            if la ~= lb then return la > lb end
            return Util.Tier(a) > Util.Tier(b)
        end)
        for _, id in ipairs(list) do
            local info = petShow and petShow[id]
            local name = info and (info.DisplayName or info.Name) or (petCfg and petCfg[id] and petCfg[id].Name) or id
            local rarity = petCfg and petCfg[id] and petCfg[id].Rarity or "Pet"
            local label = "[" .. tostring(rarity) .. "] " .. tostring(name) .. " (" .. id .. ")"
            labels[#labels + 1] = label
            ids[label] = id
        end
        PS.TargetLabels = ids
        return labels
    end

    local function Task(name, fn, done)
        return function()
            if PS.Busy then
                pnotify("Busy: " .. PS.Busy)
                return
            end
            PS.Busy = name
            task.spawn(function()
                local ok, a, b = pcall(fn)
                PS.Busy = nil
                if not ok then
                    warn("[LazyJiro]", name, tostring(a))
                    pnotify(name .. " failed; check the console")
                    return
                end
                if done then pnotify(done(a, b)) end
            end)
        end
    end

    -- UI
    local HatchCard = PetEggTab:AddCard("Egg Hatchery & Farm", "Left", "OP")
    local CleanCard = PetEggTab:AddCard("Pet Bag Cleanup", "Left")
    local DeployCard = PetEggTab:AddCard("Pet Expedition", "Left")
    local LoadoutCard = PetEggTab:AddCard("Pet Loadout & Feeding", "Right", "OP")
    local TargetCard = PetEggTab:AddCard("Target Pet Hunt & Rainbow", "Right", "OP")

    HatchCard:AddToggle({
        Name = "Skip Egg Cutscene", Description = "Hides the egg opening cutscene for instant results", Default = true,
        Callback = function(v)
            PS.Opt.SkipEggAnim = v
            task.spawn(Util.Try, MuteAnim, v)
        end,
    })
    HatchCard:AddButton({ Name = "Open Ready Eggs Now", Primary = true, Callback = Task("Open Eggs", HatchStep, function(opened, hatched)
        return ("Opened %d eggs, incubating %d eggs"):format(opened or 0, hatched or 0)
    end) })
    HatchCard:AddButton({ Name = "Farm & Fill Crown Eggs (Egg2)", Primary = false, Style = "Success", Callback = Task("Farm Eggs", function()
        return FarmEggsAndFood(6)
    end, function(eggs, foods)
        return (eggs or 0) > 0 and ("Collected %d eggs and %d fruits!"):format(eggs or 0, foods or 0) or "Egg farm complete"
    end) })
    HatchCard:AddButton({ Name = "Refill 20 Eggs & Fruits Burst", Primary = false, Callback = Task("Refill", function()
        return FarmEggsAndFood(20)
    end, function(eggs, foods)
        return (eggs or 0) > 0 and ("Refilled %d eggs and %d fruits!"):format(eggs or 0, foods or 0) or "Refill complete"
    end) })

    local rarityOptions = { "Common", "UnCommon", "Rare", "Epic", "Legendary", "Mythic", "Eternal" }
    do
        local ok, names = pcall(Shared.RarityNames)
        if ok and type(names) == "table" and #names > 0 then rarityOptions = names end
    end
    CleanCard:AddDropdown({
        Name = "Protected Rarities", Description = "Selected rarities will NEVER be deleted", Stacked = true, Multi = true,
        Options = rarityOptions, Default = { "Legendary", "Mythic", "Eternal" },
        Callback = function(set) PS.Opt.Protected = ToSet(set) end,
    })
    CleanCard:AddButton({ Name = "Clean Pet & Egg Bag Now", Primary = false, Callback = Task("Clean Bag", function()
        return CleanBag(true)
    end, function(pets, eggs)
        return ("Deleted %d pets and %d extra eggs"):format(pets or 0, eggs or 0)
    end) })

    DeployCard:AddButton({ Name = "Deploy & Claim Now", Primary = false, Style = "Success", Callback = Task("Deploy", DeployStep, function(claimed, deployed)
        return ("Claimed rewards: %s | Deployed: %d"):format(claimed and "yes" or "none", deployed or 0)
    end) })

    LoadoutCard:AddButton({ Name = "Equip Best Pets Now", Primary = true, Callback = Task("Equip Pets", EquipBest, function(changed)
        return (changed or 0) > 0 and ("Equipped %d better pets"):format(changed) or "Already using your best pets"
    end) })
    LoadoutCard:AddButton({ Name = "Feed Pet Once", Primary = false, Callback = Task("Feed Pet", FeedBest, function(fed)
        return (fed or 0) > 0 and "Fed your pet!" or "No food or no pet to feed"
    end) })
    LoadoutCard:AddButton({ Name = "Feed All Pets to Max Level Now", Primary = false, Style = "Success", Callback = Task("Feed All", FeedAllMax, function(count)
        return (count or 0) > 0 and ("Fed pets %d times"):format(count) or "Pets already max level or no food"
    end) })

    local targetDropdown = TargetCard:AddDropdown({
        Name = "Target Pet", Stacked = true, Options = { "Loading..." }, Default = "Loading...",
        Callback = function(v)
            if PS.TargetLabels[v] then PS.Opt.TargetPet = v end
        end,
    })
    task.spawn(function()
        local ok, labels = pcall(PetChoices)
        if ok and #labels > 0 then
            targetDropdown:Refresh(labels)
            targetDropdown:Set(labels[1])
            PS.Opt.TargetPet = labels[1]
        else
            if not ok then warn("[LazyJiro] pet list:", labels) end
            targetDropdown:Refresh({ "Unavailable" })
            targetDropdown:Set("Unavailable", true)
        end
    end)

    TargetCard:AddButton({ Name = "Farm & Incubate Target Egg Now", Primary = true, Callback = Task("Hunt Pet", function()
        local petId = PS.Opt.TargetPet and PS.TargetLabels[PS.Opt.TargetPet]
        if not petId then return nil, "Pick a target pet first" end
        local _, msg = FarmAndHatchTarget(petId, 1)
        return nil, msg
    end, function(_, msg) return msg or "Target egg incubating" end) })
    TargetCard:AddButton({ Name = "Lock All High-Tier Pets", Primary = false, Style = "Warning", Callback = Task("Lock Pets", LockAllHighTier, function(count)
        return ("Locked %d high-tier pets"):format(count or 0)
    end) })
    TargetCard:AddButton({ Name = "Craft Grade Up Pets Now", Primary = false, Style = "Success", Callback = Task("Grade Up", GradeUpAll, function(count)
        return (count or 0) > 0 and ("Upgraded %d pet grades!"):format(count) or "No duplicates to upgrade"
    end) })
    TargetCard:AddButton({ Name = "Craft Any Rainbow Pet Now", Primary = true, Callback = Task("Rainbow Cycle", RainbowStep, function()
        return "Rainbow craft cycle finished"
    end) })
    TargetCard:AddButton({ Name = "Craft Rainbow Fenrir (1-Click)", Primary = false, Style = "Success", Callback = Task("Rainbow Fenrir", function()
        local ok, msg = CraftRainbow(FindPetByName("fenrir", "Pet_Egg2_5"))
        return ok, msg
    end, function(_, msg) return msg end) })
    TargetCard:AddButton({ Name = "Craft 1-Click Rainbow Drake", Primary = true, Callback = Task("Rainbow Drake", function()
        local ok, msg = CraftRainbow(FindPetByName("drake", "Pet_Egg1_5"))
        return ok, msg
    end, function(_, msg) return msg end) })

    -- Mute the egg result screen when the cutscene skip is on
    task.spawn(function()
        local remote = FR("Pet", "ShowLuckResult")
        if remote and remote:IsA("RemoteEvent") then
            Window.reg(remote.OnClientEvent:Connect(function()
                if PS.Opt.SkipEggAnim then
                    task.defer(ResetVFX)
                    task.delay(0.15, ResetVFX)
                end
            end))
        end
    end)

    Window.reg({ Disconnect = function()
        PS.Alive = false
        pcall(MuteAnim, false)
    end })
end

local ClassServer = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Class_Server")
local LuckOnceRE = ClassServer:WaitForChild("LuckOnceRE")

local Classes = {
    Class_1  = { Rarity = "Common",    Layout = 1,  DisplayName = "Human" },
    Class_2  = { Rarity = "UnCommon",  Layout = 2,  DisplayName = "Goblin" },
    Class_3  = { Rarity = "UnCommon",  Layout = 3,  DisplayName = "Skeleton" },
    Class_4  = { Rarity = "Rare",      Layout = 4,  DisplayName = "Yeti" },
    Class_5  = { Rarity = "Epic",      Layout = 5,  DisplayName = "Vampire" },
    Class_6  = { Rarity = "Legendary", Layout = 6,  DisplayName = "Dragonkin" },
    Class_7  = { Rarity = "Legendary", Layout = 7,  DisplayName = "Void-Elf" },
    Class_8  = { Rarity = "Mythic",    Layout = 8,  DisplayName = "Demon" },
    Class_9  = { Rarity = "Mythic",    Layout = 9,  DisplayName = "Angel" },
    Class_10 = { Rarity = "Eternal",   Layout = 10, DisplayName = "Lavakin" },
}
local CLASS_ORDER = { "Class_1", "Class_2", "Class_3", "Class_4", "Class_5", "Class_6", "Class_7", "Class_8", "Class_9", "Class_10" }

local STOP_TIERS = { [1] = true, [2] = true, [3] = true }

local STOP_CLASSES = {}
local function setStopFrom(classId)
    STOP_CLASSES = {}
    local minLayout = Classes[classId].Layout
    for id, info in pairs(Classes) do
        if info.Layout >= minLayout then STOP_CLASSES[id] = true end
    end
end
setStopFrom("Class_8")

local NAME_LOOKUP = {}
for classId, info in pairs(Classes) do
    NAME_LOOKUP[info.DisplayName:lower()] = classId
end

local ARG_OPTIONS = { "1", "2", "3", "4", "5", "6" }
local Roll = { Auto = false, Priority = true, Run = 0, Args = {} }
for _, v in ipairs(ARG_OPTIONS) do Roll.Args[v] = false end

local optionLabels, labelToId = {}, {}
for _, id in ipairs(CLASS_ORDER) do
    local info = Classes[id]
    local label = ("%s - %s (%s)"):format(id, info.Rarity, info.DisplayName)
    table.insert(optionLabels, label)
    labelToId[label] = id
end

local RollTab = Main:AddTab("Auto Roll")
local RollCard = RollTab:AddCard("Auto Roll", "Left")
local ArgCard = RollTab:AddCard("Space", "Right")

local rollStatus = RollCard:AddLabel("Status: Ready")
local autoToggle

local function stopAutoRoll(text)
    Roll.Auto = false
    Roll.Run += 1
    if autoToggle then autoToggle:Set(false, true) end
    rollStatus:Set(text or "Status: Stopped")
end

RollCard:AddDropdown({ Name = "Stop At", Options = optionLabels, Default = optionLabels[8], Callback = function(v)
    local id = labelToId[v]
    if id then
        setStopFrom(id)
        rollStatus:Set("Will stop on " .. Classes[id].DisplayName .. " or rarer")
    end
end})

RollCard:AddToggle({ Name = "Stop on Rare", Default = true, Callback = function(v)
    Roll.Priority = v
    rollStatus:Set(v and "Stop on rare enabled" or "Stop on rare disabled")
end})

autoToggle = RollCard:AddToggle({ Name = "Auto Reroll", Default = false, Callback = function(v)
    if not v then
        stopAutoRoll("Status: Stopped")
        return
    end
    local anyOn = false
    for _, a in ipairs(ARG_OPTIONS) do
        if Roll.Args[a] then anyOn = true break end
    end
    if not anyOn then
        autoToggle:Set(false, true)
        rollStatus:Set("Enable at least one Slot toggle!")
        return
    end
    Roll.Auto = true
    Roll.Run += 1
    local run = Roll.Run
    rollStatus:Set(Roll.Priority and "Rolling... will stop on a rare class" or "Rolling...")
    task.spawn(function()
        while Roll.Auto and Roll.Run == run do
            for _, a in ipairs(ARG_OPTIONS) do
                if Roll.Args[a] then LuckOnceRE:FireServer(a) end
            end
            task.wait(0.2)
        end
    end)
end})

local slotNames = {}
for _, argVal in ipairs(ARG_OPTIONS) do table.insert(slotNames, "Slot " .. argVal) end
ArgCard:AddToggleGrid({ Name = "Slots", Items = slotNames, Columns = 2, Callback = function(name, v)
    local argVal = name:match("%d+")
    if argVal then Roll.Args[argVal] = v end
end })

local function splitNameAndTier(str)
    local name, tier = str:match("^(.-)%s*[%s_%-]%s*(%d+)$")
    if name and name ~= "" then
        return name, tonumber(tier)
    end
    return str, nil
end

local function tierAllowed(tier)
    if next(STOP_TIERS) == nil then return true end
    if tier == nil then return true end
    return STOP_TIERS[tier] == true
end

local function matchClass(value)
    if type(value) == "string" then
        if STOP_CLASSES[value] then return value end
        local clean = value:gsub("^%s+", ""):gsub("%s+$", "")

        local idOnly = clean:match("^(Class_%d+)")
        if idOnly and STOP_CLASSES[idOnly] then
            local _, tier = splitNameAndTier(clean)
            if tierAllowed(tier) then return idOnly end
        end

        local name, tier = splitNameAndTier(clean)
        local classId = NAME_LOOKUP[name:lower()]
        if classId and STOP_CLASSES[classId] then
            if tierAllowed(tier) then return classId, tier end
        end
    elseif type(value) == "number" then
        local key = "Class_" .. tostring(value)
        if STOP_CLASSES[key] then return key end
    end
    return nil
end

local function scanForHit(value, depth)
    depth = depth or 0
    if depth > 3 then return nil end
    local hit, tier = matchClass(value)
    if hit then return hit, tier end
    if type(value) == "table" then
        for _, v in pairs(value) do
            local h, t = scanForHit(v, depth + 1)
            if h then return h, t end
        end
    end
    return nil
end

local function onResultReceived(...)
    if not Roll.Auto or not Roll.Priority then return end
    for _, arg in ipairs({ ... }) do
        local hit, tier = scanForHit(arg)
        if hit then
            local info = Classes[hit]
            local tierText = tier and (" " .. tier) or ""
            stopAutoRoll("Stopped on " .. (info and info.DisplayName or hit) .. tierText .. " (" .. hit .. ")")
            return
        end
    end
end

local function hookRemote(remote)
    if remote:IsA("RemoteEvent") and remote ~= LuckOnceRE then
        remote.OnClientEvent:Connect(onResultReceived)
    end
end
for _, child in ipairs(ClassServer:GetChildren()) do hookRemote(child) end
ClassServer.ChildAdded:Connect(hookRemote)

for _, attr in ipairs({ "Class", "Result", "Roll", "LastRoll", "ClassResult" }) do
    LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
        onResultReceived(LocalPlayer:GetAttribute(attr))
    end)
end

local Tower = Main:AddTab("Tower")
local TowerFarmCard = Tower:AddCard("Dungeon", "Left")
local TowerSellCard = Tower:AddCard("Pet", "Right")

local statusLbl = TowerFarmCard:AddLabel("Status: Idle")
local roundsLbl = TowerFarmCard:AddLabel("Total Rounds: 0")

TowerFarmCard:AddToggle({ Name = "Auto Dungeon", Default = false, Callback = function(v)
    State.Running = v
    if v then task.spawn(farmLoop) else updateStatus("Idle") end
end})

TowerFarmCard:AddButton({ Name = "Force Start Dungeon", Primary = true, Callback = function()
    pcall(function() DS.TryIntoDungeonRF:InvokeServer(true, 50) end)
    Window:Notify({ Title = "Dungeon", Content = "Sent dungeon enter request.", Duration = 2 })
end})

TowerFarmCard:AddButton({ Name = "Claim Daily Reward", Primary = false, Callback = function()
    pcall(function() DS.TryClaimDailyDunTicRE:FireServer() end)
    Window:Notify({ Title = "Rewards", Content = "Daily claim sent.", Duration = 2 })
end})

TowerSellCard:AddToggle({ Name = "Auto Sell All Pets", Default = false, Callback = function(v)
    State.AutoSell = v
    if v then task.spawn(autoSellLoop) end
end})

TowerSellCard:AddToggle({ Name = "Auto Hatch Eggs", Default = false, Callback = function(v)
    State.AutoHatch = v
    if v then task.spawn(autoHatchLoop) end
end})

TowerSellCard:AddToggle({ Name = "Auto Roll Pets", Default = false, Callback = function(v)
    State.AutoRoll = v
    if v then task.spawn(autoRollLoop) end
end})

TowerSellCard:AddButton({ Name = "Sell All Now", Primary = true, Callback = function()
    local c = sellAllPets()
    Window:Notify({ Title = "Auto Sell", Content = ("Sold %d pets."):format(c), Duration = 2 })
end})

local Spawner = Main:AddTab("Spawner")

do
    local Util, GameLib, Cfg, notify = Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify

    local FORGE_COUNT_MAX = 30
    local PLAN_SLICE = 0.004
    local HUNT_BATCH = 40
    local HUNT_WORKERS = 4
    local HUNT_MAX_FORGES = 4000
    local GEAR_TYPES = { "Weapon", "Armor", "Hat" }

    local S = { Alive = true, Busy = false, Cancel = false, Slot = "Weapon", Gear = nil, Copies = 1, Labels = {} }
    local PlanCache = {}

    local function Aborted() return S.Cancel or not S.Alive end

    local function GetProfile()
        return Util.Remote("Profile", "GetTotalDataRF"):InvokeServer()
    end

    local function OreIds()
        local ids = {}
        for oreId in pairs(GameLib.Need(Cfg().Ore.Config)) do
            table.insert(ids, oreId)
        end
        table.sort(ids, function(a, b) return Util.Tier(a) > Util.Tier(b) end)
        return ids
    end

    local function OwnedOres(profile)
        local owned = {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.Type == "Ore" and (entry.Number or 0) >= 1 then
                local number = math.floor(entry.Number)
                local current = owned[entry.ID]
                if not current or number > current.number then
                    owned[entry.ID] = { uuid = uuid, number = number }
                end
            end
        end
        return owned
    end

    local function WaitAll(workers, job)
        local pending = workers
        for _ = 1, workers do
            task.spawn(function()
                Util.Try(job)
                pending -= 1
            end)
        end
        local deadline = os.clock() + 30
        while pending > 0 and os.clock() < deadline do task.wait(0.1) end
    end

    local function GearCatalog()
        local gear = {}
        local armorHelper = GameLib.Api(Cfg().Armor.Helper)
        for weaponId, weapon in pairs(GameLib.Need(Cfg().Weapon.Config)) do
            table.insert(gear, { id = weaponId, slot = "Weapon", forgeType = "Weapon", forgeable = weapon.TLevel ~= nil })
        end
        for armorId, armor in pairs(GameLib.Need(Cfg().Armor.Config)) do
            table.insert(gear, { id = armorId, slot = armorHelper.GetBigType(armorId) or "Armor", forgeType = "Armor", forgeable = armor.TLevel ~= nil })
        end
        return gear
    end

    local function GearHelper(gear)
        return GameLib.Api(gear.forgeType == "Weapon" and Cfg().Weapon.Helper or Cfg().Armor.Helper)
    end

    local function PlanFor(gear, candidates, aborted)
        local forgeUtils = GameLib.Api(ReplicatedStorage.Utils.ForgeUtils)
        local helper = GearHelper(gear)
        local bestChance, bestOre, bestCount = 0, nil, nil
        local sliceStart = os.clock()
        for count = 1, FORGE_COUNT_MAX do
            local okSplit, split = pcall(helper.GetForgePercentByNumber, count)
            if okSplit and split then
                for _, cand in ipairs(candidates) do
                    if aborted and aborted() then return nil end
                    if count <= cand.max then
                        if os.clock() - sliceStart > PLAN_SLICE then
                            task.wait()
                            sliceStart = os.clock()
                        end
                        local list = { [cand.id] = count }
                        local ok, chance = pcall(function()
                            local low, high = forgeUtils.GetForgeOreResult(list)
                            local power = forgeUtils.GetOreAvgPower(list)
                            local total = 0
                            for subType, share in pairs(split) do
                                if share > 0 then
                                    total += share * (forgeUtils.GetEquPercent(gear.forgeType, count, low, high, power, subType)[gear.id] or 0)
                                end
                            end
                            return total
                        end)
                        if ok and chance > bestChance then
                            bestChance, bestOre, bestCount = chance, cand.id, count
                        end
                    end
                end
            end
        end
        return bestChance, bestOre, bestCount
    end

    local function Label(gear, allCandidates, aborted)
        local shows = GameLib.Need(Cfg()[gear.forgeType].Show)
        local show = shows[gear.id]
        local name = ("%s [%s]"):format(show and show.DisplayName or gear.id, gear.slot)
        local chance = PlanCache[gear.id]
        if chance == nil then
            chance = PlanFor(gear, allCandidates, aborted)
            if chance == nil then return nil end
            PlanCache[gear.id] = chance
        end
        return chance > 0 and ("%s - %.2f%%"):format(name, chance * 100) or name .. " - no recipe"
    end

    local function GearChoices(slot, aborted)
        local list = {}
        for _, gear in ipairs(GearCatalog()) do
            if gear.forgeable and gear.slot == slot then
                local ok, power = pcall(GearHelper(gear).GetMainAffix, gear.id)
                table.insert(list, { gear, ok and tonumber(power) or 0 })
            end
        end
        table.sort(list, function(a, b) return a[2] > b[2] end)

        local allCandidates = {}
        for _, oreId in ipairs(OreIds()) do
            table.insert(allCandidates, { id = oreId, max = FORGE_COUNT_MAX })
        end

        local labels, byLabel = {}, {}
        for _, pair in ipairs(list) do
            if aborted() then return nil end
            local label = Label(pair[1], allCandidates, aborted)
            if not label then return nil end
            if byLabel[label] then label = label .. " #" .. tostring(pair[1].id) end
            byLabel[label] = pair[1]
            table.insert(labels, label)
        end
        return labels, byLabel
    end

    local function Anchors(profile)
        local anchors, bestPower = {}, {}
        for uuid, entry in pairs(profile.Backpack.have) do
            if entry.Type == "Weapon" or entry.Type == "Armor" or entry.Type == "Hat" then
                local helper = GameLib.Api(entry.Type == "Weapon" and Cfg().Weapon.Helper or Cfg().Armor.Helper)
                local ok, percent = pcall(helper.CheckIsBestPercent, entry.ID)
                if ok and not percent then
                    local powerOk, power = pcall(helper.GetMainAffix, entry.ID)
                    if powerOk and type(power) == "number" and power > (bestPower[entry.Type] or 0) then
                        bestPower[entry.Type] = power
                        anchors[entry.Type] = uuid
                    end
                end
            end
        end
        local keep = {}
        for _, uuid in pairs(anchors) do keep[uuid] = true end
        return keep
    end

    local function SellFresh(profile, fresh, keep)
        local protected = Anchors(profile)
        for _, uuid in pairs(profile.Backpack.equiped) do protected[uuid] = true end
        local sell = Util.Remote("Backpack", "TrySellItemRE")
        for uuid in pairs(fresh) do
            if not protected[uuid] and not keep[uuid] then
                sell:FireServer(uuid, 1)
            end
        end
    end

    local function Hunt(gear, copies)
        local forgeRF = Util.Remote("Forge", "ForgeRF")
        local got, forgedTotal = 0, 0
        local plan

        while got < copies and forgedTotal < HUNT_MAX_FORGES * copies and not Aborted() do
            local profile = GetProfile()
            local owned = OwnedOres(profile)

            if not plan or not owned[plan.oreId] or owned[plan.oreId].number < plan.count then
                local candidates = {}
                for oreId, stack in pairs(owned) do
                    table.insert(candidates, { id = oreId, max = math.min(stack.number, FORGE_COUNT_MAX) })
                end
                table.sort(candidates, function(a, b) return Util.Tier(a.id) > Util.Tier(b.id) end)
                local chance, oreId, count = PlanFor(gear, candidates, Aborted)
                if not oreId or not chance or chance <= 0 then
                    return got, Aborted() and "stopped" or "no usable ore left"
                end
                plan = { chance = chance, oreId = oreId, count = count }
            end

            local stack = owned[plan.oreId]
            local perBatch = math.min(HUNT_BATCH, math.floor(stack.number / plan.count))
            local before = {}
            for uuid in pairs(profile.Backpack.have) do before[uuid] = true end

            local remaining, succeeded = perBatch, 0
            WaitAll(HUNT_WORKERS, function()
                while remaining > 0 and not Aborted() do
                    remaining -= 1
                    local result = forgeRF:InvokeServer({ ConfigType = gear.forgeType, UUIDList = { [stack.uuid] = plan.count } })
                    if result ~= nil and result ~= false then succeeded += 1 end
                end
            end)
            forgedTotal += perBatch
            if succeeded == 0 then
                return got, Aborted() and "stopped" or "the forge was rejected"
            end

            local after = GetProfile()
            local fresh = {}
            for uuid, entry in pairs(after.Backpack.have) do
                if not before[uuid] and entry.Type ~= "Ore" and entry.Type ~= "Material" and entry.Type ~= "EnchStone" then
                    fresh[uuid] = entry
                end
            end
            local keep = {}
            for uuid, entry in pairs(fresh) do
                if entry.ID == gear.id and got < copies then
                    keep[uuid] = true
                    got += math.max(1, math.floor(entry.Number or 1))
                end
            end
            SellFresh(after, fresh, keep)
        end
        return got, got >= copies and "done" or (Aborted() and "stopped" or "forge limit reached")
    end

    local function SeasonCurrent()
        local seasons = GetProfile().Season or {}
        local bestKey, bestTier = nil, -1
        for key in pairs(seasons) do
            local tier = Util.Tier(key)
            if tier > bestTier then bestKey, bestTier = key, tier end
        end
        return bestKey and seasons[bestKey]
    end

    local function BuyExclusive()
        local goods = GameLib.Need(Cfg().Season.GoodsConfig)
        local exchange = Util.Remote("Season", "ExchangeGoodsRE")
        local bought, short = 0, 0
        for goodId, good in pairs(goods) do
            if good.Type == "Weapon" or good.Type == "Armor" or good.Type == "Hat" then
                local season = SeasonCurrent()
                if season and ((season.Goods or {})[goodId] or 0) < (good.Store or 1) then
                    if (season.SeasonCoin or 0) >= good.NeedSeasonCoin then
                        exchange:FireServer(goodId)
                        bought += 1
                        task.wait(0.5)
                    else
                        short += 1
                    end
                end
            end
        end
        return bought, short
    end

    local GearCard = Spawner:AddCard("Spawn Gear", "Left", "OP")
    local gearDropdown
    local loadToken = 0

    local function LoadGearList(slot)
        loadToken += 1
        local token = loadToken
        S.Gear = nil
        gearDropdown:Refresh({ "Loading..." })
        gearDropdown:Set("Loading...", true)
        task.spawn(function()
            local ok, labels, byLabel = pcall(GearChoices, slot, function() return token ~= loadToken or not S.Alive end)
            if token ~= loadToken then return end
            if ok and labels and #labels > 0 then
                S.Labels = byLabel
                gearDropdown:Refresh(labels)
                gearDropdown:Set(labels[1])
            else
                if not ok then warn("[LazyJiro] gear list:", labels) end
                gearDropdown:Refresh({ "Unavailable" })
                gearDropdown:Set("Unavailable", true)
                notify("Gear list could not be read", "Warning")
            end
        end)
    end

    GearCard:AddDropdown({ Name = "Type", Stacked = true, Options = GEAR_TYPES, Default = "Weapon", Callback = function(v)
        S.Slot = v
        LoadGearList(v)
    end })

    gearDropdown = GearCard:AddDropdown({ Name = "Gear", Stacked = true, Description = "Strongest first. Exclusive gear is shop only", Options = { "Loading..." }, Default = "Loading...", Callback = function(v)
        S.Gear = v
    end })

    local copiesInput
    copiesInput = GearCard:AddInput({ Name = "Copies", Stacked = true, Default = "1", Placeholder = "1", Callback = function(text)
        local n = math.max(1, math.floor(tonumber(text) or 1))
        S.Copies = n
        copiesInput:Set(tostring(n))
    end })

    local spawnButton
    spawnButton = GearCard:AddButton({ Name = "Spawn Gear", Primary = true, Callback = function()
        if S.Forging then
            S.Cancel = true
            spawnButton:SetText("Stopping...")
            return
        end
        if S.Busy then return notify("Busy. Wait for the current job to finish", "Warning") end
        local gear = S.Gear and S.Labels[S.Gear]
        if not gear then return notify("Pick a gear first", "Warning") end
        S.Busy, S.Forging, S.Cancel = true, true, false
        spawnButton:SetText("Stop Forging")
        local copies = S.Copies
        notify("Forging " .. tostring(gear.id) .. "...")
        local ok, got, reason = pcall(Hunt, gear, copies)
        S.Busy, S.Forging = false, false
        spawnButton:SetText("Spawn Gear")
        if not ok then
            warn("[LazyJiro] forge gear:", got)
            notify("Forge failed; check the console", "Error")
        elseif got >= copies then
            notify(("Got %d x %s"):format(got, tostring(gear.id)), "Success")
        else
            notify(("Got %d/%d (%s)"):format(got, copies, reason or "stopped"), "Warning")
        end
    end })

    GearCard:AddButton({ Name = "Buy Exclusive Gear", Primary = false, Callback = function()
        if S.Busy then return notify("Busy. Wait for the current job to finish", "Warning") end
        S.Busy = true
        local ok, bought, short = pcall(BuyExclusive)
        S.Busy = false
        if not ok then
            warn("[LazyJiro] buy exclusive:", bought)
            notify("Could not buy; check the console", "Error")
        elseif bought > 0 then
            notify(("Bought %d exclusive piece(s)"):format(bought), "Success")
        elseif short > 0 then
            notify("Not enough season coins for the remaining exclusive gear", "Warning")
        else
            notify("Nothing left to buy right now")
        end
    end })

    LoadGearList(S.Slot)

    Window.reg({ Disconnect = function() S.Alive = false end })
end

task.spawn(function()
    while task.wait(0.5) do
        roundsLbl:Set("Total Rounds: " .. State.Rounds)
        statusLbl:Set("Status: " .. State.Status)
    end
end)

Window:AddCategory("Miscellaneous")
local Settings = Window:AddPage({ Name = "Settings" })
local InterfaceTab = Settings:AddTab("Interface")
local UiCard = InterfaceTab:AddCard("UI Settings", "Left")
UiCard:AddKeybind({ Name = "Toggle UI Key", Default = Window.ToggleKey, Changed = function(k) Window:SetToggleKey(k) end })
UiCard:AddToggle({ Name = "Falling Petals", Default = true, Callback = function(v) Window:SetPetals(v) end })
UiCard:AddSlider({ Name = "UI Scale", Min = 0.6, Max = 1.3, Default = 1, Increment = 0.05, Callback = function(v) Window:SetScale(v) end })
UiCard:AddButton({ Name = "Destroy UI", Primary = false, Callback = function() Window:Destroy() end })

local AntiAfk = { Enabled = true, Blocked = 0 }
local AfkCard = InterfaceTab:AddCard("Anti AFK", "Right")
local afkStatus
AfkCard:AddToggle({ Name = "Anti AFK", Default = true, Callback = function(v)
    AntiAfk.Enabled = v
    if afkStatus then afkStatus:Set(v and "Status: Protected" or "Status: Off") end
end })
AfkCard:AddLabel("Stay online all night. Roblox boots idle players after 20 minutes, so this quietly taps for you and keeps you in the game while you farm.")
afkStatus = AfkCard:AddLabel("Status: Protected")
local afkCount = AfkCard:AddLabel("Idle kicks blocked: 0")

pcall(function()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if not AntiAfk.Enabled then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        AntiAfk.Blocked = AntiAfk.Blocked + 1
        afkCount:Set("Idle kicks blocked: " .. AntiAfk.Blocked)
    end)
end)

Window:Notify({ Title = "Lazy Jiro", Content = "Loaded (Forge page build). Press RightShift to hide or show.", Duration = 5 })
Intro.Set("Almost ready", 0.9)
if getgenv then getgenv().LazyJiroWindow = Window end

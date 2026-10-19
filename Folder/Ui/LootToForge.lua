local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jiroscriptsss/LazyHub/main/LazyJiroUI.lua"))()

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

-- Same logic as your plain-UI script: 5 workers with a short wait between rounds.
-- Workers are spawned once per toggle-on; RunId stops old ones when you toggle off.
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
    -- put max HP back when turned off
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
        warn("[Lazy Jiro Hub] EnemyFolder not found")
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
    Name      = "LAZY JIRO HUB",
    ToggleKey = Enum.KeyCode.RightShift,
    Link      = "https://github.com/jiroscriptsss/LazyHub",
})

-- the menu library is hosted separately; stop early if the hosted copy is older than this script needs
if (Lib.Version or 0) < 4 then
    warn("[Lazy Jiro Hub] LazyJiroUI.lua on GitHub is outdated. Upload the new one, wait a few minutes, then run again.")
    Window:Notify({ Title = "Update needed", Content = "LazyJiroUI.lua on GitHub is outdated. Upload the new file, wait a few minutes, then run again.", Duration = 12 })
    return
end

Window:AddCategory("Main")
local Main = Window:AddPage({ Name = "Farm" })

local Farming = Main:AddTab("Farming")

local Shared = {}

-- ============================================================
--  STAGE & COMBAT (ported from the old PixeL script)
-- ============================================================
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

    -- game Config folder is looked up lazily so a slow load never blocks the menu
    local function Cfg()
        local folder = ReplicatedStorage:WaitForChild("Config", FarmCfg.LoadTimeout)
        if not folder then error("ReplicatedStorage.Config not found", 0) end
        return folder
    end

    local Util = {}
    function Util.Try(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Lazy Jiro Hub]", err) end
        return ok, err
    end
    function Util.Tier(id) return tonumber(tostring(id):match("%d+")) or 0 end

    -- ---------- game modules (needs thread identity on some executors) ----------
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
                warn("[Lazy Jiro Hub] require", module:GetFullName(), firstErr)
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

    -- ---------- remote finder (survives renamed remotes like Dungeon -> Dungeon_Server) ----------
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
                    print(("[Lazy Jiro Hub] remote %s -> %s"):format(key, hit:GetFullName()))
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

    -- ---------- job runner (retry backoff, auto-stops a feature that keeps failing) ----------
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
            warn("[Lazy Jiro Hub]", key, tostring(result))
        end
        streak.count += 1
        streak.nextTry = now + math.min(FarmCfg.RetryMax, FarmCfg.RetryBase * 2 ^ math.min(streak.count - 1, 8))
        if streak.count >= FarmCfg.MaxFailures and now - streak.since >= FarmCfg.FailWindow then
            failures[key] = nil
            Farm.Opt[key] = false
            local reason = tostring(result):match("[^\n]*")
            warn("[Lazy Jiro Hub]", key, "stopped:", reason)
            local toggle = Farm.Toggles[key]
            if toggle then toggle:Set(false, true) end
            notify(key .. " stopped: " .. reason, "Warning")
        end
        return false, result
    end

    -- one persistent worker per fast feature, even with rapid off/on toggling
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
            if not ok then warn("[Lazy Jiro Hub]", key, err) end
        end)
    end

    local function Exclusive(name, fn, ...)
        if Farm.Lock then return false end
        Farm.Lock = name
        local ok, result = Util.Try(fn, ...)
        Farm.Lock = nil
        return ok, result
    end

    -- ---------- ore + stage ----------
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

    -- Failed/unclaimed batches are kept so retries never open a new stage over pending loot.
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

    -- ---------- combat ----------
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

    -- ---------- UI ----------
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
            warn("[Lazy Jiro Hub] stage list:", stages)
            stageDropdown:Refresh({ "Unavailable" })
            stageDropdown:Set("Unavailable", true)
            notify("Stage list could not be read. Auto Collect Ore will use the best stage if it can")
        end
    end)

    task.spawn(function()
        local ok, names = pcall(RarityNames)
        if ok and type(names) == "table" and #names > 0 then
            rarityDropdown:Refresh(names)
            rarityDropdown:Set(names) -- everything selected by default
        else
            warn("[Lazy Jiro Hub] rarity list:", names)
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
            warn("[Lazy Jiro Hub] exit fight:", err)
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

    -- kills of rare ore bosses the moment they spawn
    task.spawn(function()
        local ok, err = pcall(function()
            local event = Util.Remote("SuperLoot", "RefreshSuperLootRE")
            Window.reg(event.OnClientEvent:Connect(function(_, uuid)
                if Farm.Opt.SuperLootAura then
                    task.spawn(Util.Try, SuperKill, uuid)
                end
            end))
        end)
        if not ok then warn("[Lazy Jiro Hub] ore boss hook:", err) end
    end)

    -- stop every worker when the UI is destroyed
    Window.reg({ Disconnect = function() Farm.Alive = false end })

    Shared.Util, Shared.GameLib, Shared.Cfg, Shared.notify = Util, GameLib, Cfg, notify
    Shared.Ore, Shared.Stage, Shared.Farm, Shared.RarityNames = Ore, Stage, Farm, RarityNames
end

-- ============================================================
--  FORGE (ported from the old PixeL script)
-- ============================================================
local ForgeTab = Main:AddTab("Forge")
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

    -- ---------- data ----------
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

    -- ---------- ores ----------
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

    -- adds ore to a stack you already own (negative "sell" amount)
    local function AddOre(uuid, amount)
        Util.Remote("Backpack", "TrySellItemRE"):FireServer(uuid, -math.abs(amount))
    end

    -- farms stages until the wanted ore drops once, so it can then be topped up
    local function AcquireOre(oreId)
        -- never open a new stage over a pending Auto Collect Ore batch
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

    -- ---------- selling the forge leftovers ----------
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
        -- items you locked in game are never sold
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

    -- ---------- forging ----------
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

    -- ---------- auto loop ----------
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
                        if fails == 1 then warn("[Lazy Jiro Hub] Auto Forge:", tostring(err)) end
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
            -- toggled off and on again while the old loop was winding down
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
                warn("[Lazy Jiro Hub] Forge Now:", tostring(result))
                fnotify("Forge failed; check the console")
            elseif (result or 0) > 0 then
                fnotify(("Forged %d time(s)"):format(result))
            else
                fnotify("Nothing forged. Check Forge Ore Rarity and Keep Per Ore")
            end
        end)
    end

    -- ---------- UI ----------
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

    -- lists are read from the game after the menu is up so a slow load never blocks it
    task.spawn(function()
        local ok, labels = pcall(OreChoices)
        if ok and #labels > 0 then
            oreDropdown:Refresh(labels)
            oreDropdown:Set(FC.OwnedLabel, true)
        else
            warn("[Lazy Jiro Hub] forge ore list:", labels)
            fnotify("Ore list could not be read, only Owned ores will work")
        end
    end)

    task.spawn(function()
        local ok, names = pcall(Shared.RarityNames)
        if ok and type(names) == "table" and #names > 0 then
            rarityDropdown:Refresh(names)
            rarityDropdown:Set(names) -- everything selected by default
        else
            warn("[Lazy Jiro Hub] forge rarity list:", names)
            rarityDropdown:Refresh({ "Unavailable" })
            rarityDropdown:Set({}, true)
            fnotify("Rarity list could not be read, so Owned ores can't be filtered")
        end
    end)

    Window.reg({ Disconnect = function() F.Alive = false end })
end

-- ============================================================
--  AUTO ROLL (class reroll)
-- ============================================================
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

-- Tier filter (empty {} = any tier)
local STOP_TIERS = { [1] = true, [2] = true, [3] = true }

-- Stops on the chosen class and anything rarer (default Demon = Demon / Angel / Lavakin)
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

-- Result detection
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

-- ============================================================
--  FORGE GEAR (hunts a chosen weapon/armor/hat with the ore you own)
-- ============================================================
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

    -- ---------- data ----------
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

    -- ---------- gear catalog and forge chances ----------
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

    -- candidates = { { id = oreId, max = highestOreCountAllowed }, ... }; returns chance, oreId, count (nil if aborted)
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

    -- ---------- selling the forge leftovers (new items only) ----------
    -- keeps the strongest piece of each type so a lucky better roll is never sold
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

    -- ---------- the hunt ----------
    -- Forges with the best recipe from ore you already own, keeps copies of the target, sells the rest.
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

    -- ---------- season shop ----------
    local function SeasonCurrent()
        local seasons = GetProfile().Season or {}
        local bestKey, bestTier = nil, -1
        for key in pairs(seasons) do
            local tier = Util.Tier(key)
            if tier > bestTier then bestKey, bestTier = key, tier end
        end
        return bestKey and seasons[bestKey]
    end

    -- buys every exclusive weapon/armor/hat you already have enough season coins for
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

    -- ---------- UI ----------
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
                if not ok then warn("[Lazy Jiro Hub] gear list:", labels) end
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
            warn("[Lazy Jiro Hub] forge gear:", got)
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
            warn("[Lazy Jiro Hub] buy exclusive:", bought)
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

-- Anti AFK: Roblox kicks idle players after ~20 minutes. A fake right-click on every idle event resets that timer.
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

Window:Notify({ Title = "Lazy Jiro Hub", Content = "Loaded. Press RightShift to hide or show.", Duration = 5 })

local base = "https://raw.githubusercontent.com/jiroscriptsss/LazyHub/main/Games/"

-- [GameId] = "FileName.lua" (file lives in the Games folder)
-- Find a game's ID by running: print(game.GameId, game.PlaceId)
local Games = {
    [0] = "DungeonGame.lua", -- replace 0 with the dungeon game's real GameId
}

local file = Games[game.GameId]

if not file then
    warn("[Lazy Jiro Hub] Game not supported: " .. tostring(game.GameId))
    return
end

local ok, src = pcall(function() return game:HttpGet(base .. file) end)
if not ok then
    warn("[Lazy Jiro Hub] Could not download " .. file .. ": " .. tostring(src))
    return
end

local fn, err = loadstring(src)
if not fn then
    warn("[Lazy Jiro Hub] Script error in " .. file .. ": " .. tostring(err))
    return
end
fn()

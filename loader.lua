-- Example Lua Script: Player Notification
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local function greetPlayer(player)
    local msg = "Welcome to the server, " .. player.Name .. "!"
    print(msg)
    return msg
end

greetPlayer(localPlayer or { Name = "GuestUser" })

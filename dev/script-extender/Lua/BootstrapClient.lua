local Diagnostics = Ext.Require("Client/RadialProbe.lua")

Diagnostics.Register({ Auto = true })

-- Dev-only, read-only inventory snapshots; never shipped in CAM PAK.
local GameplayInventory = Ext.Require("Client/GameplayInventoryProbe.lua")
GameplayInventory.Register()

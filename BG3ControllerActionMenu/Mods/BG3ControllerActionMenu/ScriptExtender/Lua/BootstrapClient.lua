local Diagnostics = Ext.Require("Client/RadialProbe.lua")

-- First-run candidate builds collect bounded controller/UI diagnostics automatically.
-- The recorder never executes discovered commands; it only observes state and CanExecute.
Diagnostics.Register({ Auto = true })

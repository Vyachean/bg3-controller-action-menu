local Probe = Ext.Require("Client/RadialProbe.lua")

-- Keep the runtime probe available as a manual diagnostic fallback without
-- scanning the UI tree on ordinary controller input.
Probe.Register({ Auto = false })

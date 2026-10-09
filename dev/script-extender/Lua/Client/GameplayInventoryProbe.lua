-- Development-only live UI inventory capture. NEVER package under Mods/.
-- Read-only with respect to BG3: does not call action/slot commands,
-- mutate UI view-model properties or iterate game entities/saves.
-- Only output is a bounded JSON report in Script Extender's diagnostics dir.
local Probe = {}
local OUT = "BG3ControllerActionMenu/gameplay-inventory-raw.json"
local MAX_SNAPSHOTS = 8
local MAX_ENTRIES_PER_COLLECTION = 512
local MAX_ENTRIES_PER_SNAPSHOT = 2600
local MAX_ERRORS = 50
local registered = false
local snapshots = {}
local errors = {}
local pending = 0
local autoRequests = 0
local usedSlots = 0
local seenAutoStates = {}

local function attempt(label, fn)
    local ok, value = pcall(fn)
    if ok then return value end
    if #errors < MAX_ERRORS then
        errors[#errors + 1] = { Source = label, Message = tostring(value) }
    end
    return nil
end

local function prop(v, name)
    if v == nil then return nil end
    local ok, value = pcall(function() return v[name] end)
    if ok then return value end
    return nil
end

local function describe(v)
    if v == nil then return nil end
    local result = {
        ObjectType = tostring(prop(v, "Type") or type(v)),
        -- Name is display-only. Never treat it as a unique executable ID.
        DisplayName = tostring(prop(v, "Name") or ""),
    }
    for _, field in ipairs({
        "SlotType", "ActionId", "SpellId", "PrototypeID", "StatId",
        "PassiveName", "SpellSlotLevel", "RootSpell", "UUID",
        "CanUse", "IsActive", "IsModified", "IsMetaMagic",
        "IsContainer", "IsEquipment", "Resource", "Cost",
        "TypeId", "Level", "Value", "MaxValue", "HotBarType",
    }) do
        local value = prop(v, field)
        if type(value) == "string" or type(value) == "boolean" or type(value) == "number" then
            result[field] = value
        end
    end
    return result
end

local function collectionCount(items)
    local count = attempt("collection.Count", function() return items.Count end)
    if type(count) == "number" and count >= 0 then return count end
    count = attempt("collection.length", function() return #items end)
    if type(count) == "number" and count >= 0 then return count end
    return nil
end

local function getIndex(items, index)
    local ok, value = pcall(function() return items[index] end)
    if ok then return value end
    return nil
end

local function collection(items, route, expandNested)
    local output = { Route = route, Count = nil, Observed = 0, Items = {}, Complete = false }
    if items == nil then
        output.Reason = "native-view-model-provider-unavailable"
        return output
    end
    local count = collectionCount(items)
    output.Count = count
    if type(count) ~= "number" then
        output.Reason = "native-collection-count-unavailable"
        return output
    end
    if count == 0 then
        output.Complete = true
        return output
    end
    -- Noesis/C# IList can be zero-based; Lua proxy tables can be one-based.
    -- Detect the indexing contract instead of silently omitting first items.
    local base = getIndex(items, 0) ~= nil and 0 or 1
    output.IndexBase = base
    local take = math.min(count, MAX_ENTRIES_PER_COLLECTION, MAX_ENTRIES_PER_SNAPSHOT - usedSlots)
    for index = 0, take - 1 do
        local item = getIndex(items, base + index)
        if item == nil then
            output.Reason = "missing-item-at-index-" .. tostring(base + index)
            return output
        end
        local entry = { SourceIndex = base + index, Value = describe(item) }
        local inner = prop(item, "Content")
        if inner ~= nil then entry.Content = describe(inner) end
        if expandNested then
            local slots = prop(item, "SlotList")
            if slots ~= nil then
                entry.SlotList = collection(slots, route .. "[" .. tostring(base + index) .. "].SlotList", false)
            end
            local actions = prop(item, "Actions")
            if actions ~= nil then
                entry.Actions = collection(actions, route .. "[" .. tostring(base + index) .. "].Actions", false)
            end
        end
        output.Items[#output.Items + 1] = entry
        usedSlots = usedSlots + 1
    end
    output.Observed = #output.Items
    output.Complete = output.Observed == count
    if not output.Complete then
        output.Reason = "safety-entry-limit"
        output.Truncated = true
    end
    return output
end

local function findPage()
    local root = attempt("Ext.UI.GetRoot", function() return Ext.UI.GetRoot() end)
    local content = root and attempt("ContentRoot", function() return root:Find("ContentRoot") end)
    if not content then return nil end
    return attempt("ActionRadials", function() return content:Find("ActionRadials") end)
end

local function resourcePreview(v)
    if v == nil then return nil end
    local resource = prop(v, "ActionResource")
    return {
        Preview = describe(v),
        ActionResource = describe(resource),
        ActionResourceName = tostring(prop(resource, "Name") or ""),
    }
end

local function activeSlotTrace(dc, current)
    local slot = prop(dc, "CurrentActiveSlot")
    local spell = slot and prop(slot, "Spell")
    local variants = spell and prop(spell, "SpellUpcast")
    local uiData = current and prop(current, "UIData")
    local activeTask = uiData and prop(uiData, "ActiveTask")
    local upcast = activeTask and prop(activeTask, "Upcast")
    return {
        CurrentSingleHotbarFilter = tostring(prop(dc, "CurrentSingleHotbarFilter") or ""),
        ResourceFilter = describe(prop(dc, "ResourceFilter")),
        CurrentActiveSlot = describe(slot),
        CurrentActiveSlotContent = slot and describe(prop(slot, "Content")) or nil,
        CurrentActiveSpell = describe(spell),
        NativeSpellUpcastVariants = collection(
            variants,
            "CurrentActiveSlot.Spell.SpellUpcast",
            false
        ),
        ActiveTaskUpcastCostSummary = collection(
            upcast and prop(upcast, "CostSummary"),
            "CurrentPlayer.UIData.ActiveTask.Upcast.CostSummary",
            false
        ),
    }
end

local function uiCollection(page, name)
    local node = attempt(name, function() return page:Find(name) end)
    if not node then return { Name = name, Found = false, Complete = false } end
    local focus = prop(node, "LocalFocus")
    local data = focus and prop(focus, "DataContext")
    return {
        Name = name,
        Found = true,
        IsEnabled = prop(node, "IsEnabled"),
        SelectedIndex = prop(node, "SelectedIndex"),
        LocalFocus = describe(data),
        Items = collection(prop(node, "ItemsSource"), "UI." .. name .. ".ItemsSource", false),
    }
end

local function snapshot(reason)
    if #snapshots >= MAX_SNAPSHOTS then return end
    usedSlots = 0
    local page = findPage()
    if not page then return end
    local dc = prop(page, "DataContext")
    local current = prop(dc, "CurrentPlayer")
    local character = prop(current, "SelectedCharacter")
    local props = prop(character, "PlayerCharacterProperties")
    local inv = prop(character, "Inventory")
    local stats = prop(character, "Stats")
    local shownDeck = prop(dc, "CurrentShownDeck")
    local single = prop(dc, "SingleHotBar")
    local modeNode = attempt("provider-mode", function()
        return page:Find("CAM_ProviderModeMarker")
    end)
    local resourceTabs = attempt("resource-tabs", function()
        return page:Find("CAM_ResourceTabs")
    end)
    local currentMode = tostring(prop(modeNode, "Tag") or "")
    local resourceIndex = tostring(prop(resourceTabs, "SelectedIndex") or "")
    local nestedSignature = table.concat({
        tostring(prop(dc, "IsShowingAContainerWithVariants")),
        tostring(prop(dc, "IsSelectingUpcastedSpell")),
        tostring(prop(dc, "IsShowingItemsToThrow"))
    }, ":")
    local fingerprint = currentMode .. ":" .. resourceIndex .. ":" .. nestedSignature
    if reason ~= "manual-console-command" and seenAutoStates[fingerprint] then
        return
    end
    seenAutoStates[fingerprint] = true
    local fields = {
        {"KeyboardHotBars", props and prop(props, "KeyboardHotBars"), true},
        {"ControllerHotBars", props and prop(props, "ControllerHotBars"), true},
        {"PassivesHotBar.SlotList", props and prop(prop(props, "PassivesHotBar"), "SlotList"), false},
        {"FixedSideBar.SlotList", props and prop(prop(props, "FixedSideBar"), "SlotList"), false},
        {"SpellsAndActions", props and prop(props, "SpellsAndActions"), true},
        {"Inventory.Slots", inv and prop(inv, "Slots"), false},
        {"Stats.Passives", stats and prop(stats, "Passives"), false},
        {"CurrentShownDeck.SlotList", shownDeck and prop(shownDeck, "SlotList"), false},
        {"SingleHotBar.SlotList", single and prop(single, "SlotList"), false},
    }
    local snap = {
        Id = #snapshots + 1,
        Reason = reason,
        GameVersion = tostring(attempt("GameVersion", function() return Ext.Utils.GameVersion() end) or "unknown"),
        SelectedCharacterPresent = character ~= nil,
        NativeSourceCollections = {},
        CamVisibleLists = {},
        CamModeMarker = currentMode,
        CamResourceSelectedIndex = prop(resourceTabs, "SelectedIndex"),
        CamSelectedResource = resourcePreview(prop(resourceTabs, "SelectedItem")),
        NativeFilterAndUpcast = activeSlotTrace(dc, current),
        AutoStateFingerprint = fingerprint,
        ActionRadialsSlotTag = describe(prop(page, "Tag")),
        NestedFlags = {
            IsShowingAContainerWithVariants = prop(dc, "IsShowingAContainerWithVariants"),
            IsSelectingUpcastedSpell = prop(dc, "IsSelectingUpcastedSpell"),
            IsShowingItemsToThrow = prop(dc, "IsShowingItemsToThrow"),
        },
        -- Strong identity needs exact BG3 VM and action/reference equivalence.
        -- Raw catalog objects are NOT executable VMHotBarSlot parameters.
        ReadyForExecutableIdentityComparison = false,
        ProofBoundary = "native-and-cam-source-preview-only; no stable shared executable identity proved",
    }
    for _, field in ipairs(fields) do
        snap.NativeSourceCollections[field[1]] = collection(field[2], field[1], field[3])
    end
    for _, name in ipairs({"HotBarList", "CAM_FixedSideBarList", "CAM_ResourceTabs"}) do
        snap.CamVisibleLists[name] = uiCollection(page, name)
    end
    snap.ObservedItems = usedSlots
    snap.SourceCatalogComplete = true
    for _, value in pairs(snap.NativeSourceCollections) do
        if not value.Complete then snap.SourceCatalogComplete = false end
    end
    snapshots[#snapshots + 1] = snap
    local report = {
        SchemaVersion = 2,
        Probe = "CAM-dev-read-only-gameplay-inventory",
        Safety = {
            GameStateMutated = false,
            OutputFile = OUT,
            MaxSnapshots = MAX_SNAPSHOTS,
            MaxEntriesPerCollection = MAX_ENTRIES_PER_COLLECTION,
            MaxEntriesPerSnapshot = MAX_ENTRIES_PER_SNAPSHOT,
        },
        Snapshots = snapshots,
        Errors = errors,
        -- This is intentionally NOT tools/compare-runtime-gameplay.py's
        -- complete nativeExecutable / camExecutable observation schema.
        RequiresNativeExecutableIdentityAdapter = true,
        UpcastTraceSemantics = "observation-only; selected resource level/type, filtered slots, current active slot and native variants are not executable identity proof",
    }
    local json = attempt("serialize", function()
        return Ext.Json.Stringify(report, { Beautify = true, StringifyInternalTypes = true })
    end)
    if type(json) == "string" then
        attempt("write-diagnostic-json", function() return Ext.IO.SaveFile(OUT, json) end)
    end
end

function Probe.Register()
    if registered then return end
    registered = true
    attempt("register-manual-command", function()
        Ext.RegisterConsoleCommand("cam_gameplay_inventory", function()
            snapshot("manual-console-command")
        end)
    end)
    -- A bounded automatic snapshot after the native radial is open avoids
    -- asking the operator to visit every action or run a console command.
    -- This is development-only; no input is consumed or remapped.
    attempt("register-controller-observer", function()
        Ext.Events.ControllerButtonInput:Subscribe(function(event)
            if prop(event, "Pressed") ~= true or
               autoRequests >= MAX_SNAPSHOTS or pending >= 1 then return end
            -- Do not waste the small automatic budget on unrelated movement
            -- before the action radial exists in the Noesis UI tree.
            if not findPage() then return end
            autoRequests = autoRequests + 1
            local requestId = autoRequests
            pending = pending + 1
            Ext.Timer.WaitForRealtime(350, function()
                pending = pending - 1
                snapshot("controller-observation-" .. tostring(requestId))
            end)
        end)
    end)
end

return Probe

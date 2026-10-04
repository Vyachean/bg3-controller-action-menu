local Diagnostics = {}

local OUTPUT_FILE = "BG3ControllerActionMenu/diagnostics.json"
local BUILD_ID = "0.0.5-first-run-diagnostics"
local MAX_ERRORS = 120
local MAX_INPUTS = 160
local MAX_SNAPSHOTS = 120
local MAX_PROPERTY_NAMES = 500
local MAX_COLLECTION_PREVIEW = 10
local MAX_RELEVANT_NODES = 40
local MAX_SCAN_NODES = 3500
local MAX_SCAN_DEPTH = 18
local AUTO_PRESSED_LIMIT = 36

local registered = false
local pressedCount = 0

local report = {
    Build = BUILD_ID,
    Environment = {},
    Summary = {
        SessionLoaded = false,
        CustomPageSeen = false,
        VanillaRadialSeen = false,
        DCHotBarSeen = false,
        ActionGroupsSeen = false,
        FocusedActionSeen = false,
        SingleHotBarSeen = false,
        DiagnosticsCompleteEnough = false,
    },
    Inputs = {},
    Snapshots = {},
    Errors = {},
}

local function rawNow()
    local ok, value = pcall(function()
        return Ext.Timer.MonotonicTime()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return 0
end

local function recordError(context, err)
    if #report.Errors >= MAX_ERRORS then
        return
    end
    report.Errors[#report.Errors + 1] = {
        T = rawNow(),
        Context = context,
        Error = tostring(err),
    }
end

local function safe(context, fn, quiet)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    if not quiet then
        recordError(context, result)
    end
    return nil
end

local function stringify(value)
    if value == nil then
        return nil
    end

    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    end

    local result = safe("stringify:" .. kind, function()
        return tostring(value)
    end)
    return result or ("<" .. kind .. ">")
end

local function objectType(value)
    if value == nil then
        return nil
    end

    local kind = type(value)
    if kind ~= "userdata" then
        return kind
    end

    return stringify(safe("object.Type", function()
        return value.Type
    end)) or "userdata"
end

local function gameState()
    return stringify(safe("GetGameState", function()
        return Ext.Utils.GetGameState()
    end)) or "Unknown"
end

local function countOf(value)
    if value == nil then
        return nil
    end

    local count = safe("count:#", function()
        return #value
    end, true)
    if type(count) == "number" then
        return count
    end

    count = safe("count:.Count", function()
        return value.Count
    end, true)
    if type(count) == "number" then
        return count
    end

    return nil
end

local function sortedKeys(map)
    local keys = {}
    if type(map) ~= "table" then
        return keys
    end

    for key in pairs(map) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function propertyBag(object, context)
    if object == nil then
        return nil
    end

    local props = safe(context .. ":GetAllProperties", function()
        return object:GetAllProperties()
    end)

    if type(props) == "table" then
        return props
    end

    return nil
end

local function propertyNames(object, context)
    local props = propertyBag(object, context)
    if not props then
        return {}
    end

    local keys = sortedKeys(props)
    if #keys > MAX_PROPERTY_NAMES then
        local trimmed = {}
        for i = 1, MAX_PROPERTY_NAMES do
            trimmed[i] = keys[i]
        end
        return trimmed, true
    end
    return keys, false
end

local function commandInfo(value, parameter, context)
    if value == nil then
        return nil
    end

    local canExecuteMember = safe(context .. ":CanExecuteMember", function()
        return value.CanExecute
    end, true)
    local executeMember = safe(context .. ":ExecuteMember", function()
        return value.Execute
    end, true)

    if canExecuteMember == nil or executeMember == nil then
        return nil
    end

    return {
        Type = objectType(value),
        CanExecute = safe(context .. ":CanExecute", function()
            return value:CanExecute(parameter)
        end),
    }
end

local function simpleKnownProperties(object, context)
    local result = {}
    local names = {
        "Name",
        "FileName",
        "Visibility",
        "IsVisible",
        "IsEnabled",
        "ActualWidth",
        "ActualHeight",
        "Metadata",
        "Layout",
        "PanelContentType",
        "AreRadialsOpen",
        "IsShowingAContainerWithVariants",
        "IsSelectingUpcastedSpell",
        "CanUse",
        "IsContainer",
        "IsActive",
        "SlotType",
        "BoundEvent",
        "ActionId",
        "PrototypeID",
        "PassiveName",
        "SpellSlotLevel",
        "HotBarType",
    }

    for _, name in ipairs(names) do
        local value = safe(context .. ":" .. name, function()
            return object[name]
        end, true)
        if value ~= nil then
            result[name] = stringify(value)
        end
    end

    return result
end

local function describeAction(action, context)
    if action == nil then
        return nil
    end

    return {
        Type = objectType(action),
        Values = simpleKnownProperties(action, context),
        Properties = propertyNames(action, context),
    }
end

local function collectionPreview(collection, context, itemDescriber)
    local count = countOf(collection)
    local result = {
        Count = count,
        Items = {},
    }

    if type(count) ~= "number" then
        return result
    end

    local limit = math.min(count, MAX_COLLECTION_PREVIEW)
    for i = 1, limit do
        local item = safe(context .. ":item[" .. i .. "]", function()
            return collection[i]
        end)
        if item ~= nil then
            result.Items[#result.Items + 1] = itemDescriber(item, context .. ":item[" .. i .. "]")
        end
    end

    return result
end

local function describeActionGroup(group, context)
    if group == nil then
        return nil
    end

    local actions = safe(context .. ":Actions", function()
        return group.Actions
    end)

    return {
        Type = objectType(group),
        Name = stringify(safe(context .. ":Name", function()
            return group.Name
        end)),
        Values = simpleKnownProperties(group, context),
        Actions = collectionPreview(actions, context .. ":Actions", describeAction),
    }
end

local function describeHotbar(bar, context)
    if bar == nil then
        return nil
    end

    local slots = safe(context .. ":SlotList", function()
        return bar.SlotList
    end)

    return {
        Type = objectType(bar),
        Values = simpleKnownProperties(bar, context),
        SlotList = collectionPreview(slots, context .. ":SlotList", describeAction),
    }
end

local function nodeName(node)
    return stringify(safe("node.Name", function()
        return node.Name
    end, true)) or ""
end

local function nodeFileName(node)
    return stringify(safe("node.FileName", function()
        return node.FileName
    end, true)) or ""
end

local function nodeType(node)
    return stringify(safe("node.Type", function()
        return node.Type
    end, true)) or objectType(node)
end

local function describeNodeShallow(node, context)
    if node == nil then
        return nil
    end

    local dc = safe(context .. ":DataContext", function()
        return node.DataContext
    end, true)

    return {
        Name = nodeName(node),
        FileName = nodeFileName(node),
        Type = nodeType(node),
        Values = simpleKnownProperties(node, context),
        DataContextType = objectType(dc),
    }
end

local function describeFocused(page, context)
    if page == nil then
        return nil, nil
    end

    local focused = safe(context .. ":FocusedElement", function()
        return page.FocusedElement
    end, true)
    if focused == nil then
        return nil, nil
    end

    local dc = safe(context .. ":FocusedElement.DataContext", function()
        return focused.DataContext
    end, true)

    if dc ~= nil then
        report.Summary.FocusedActionSeen = true
    end

    return {
        Node = describeNodeShallow(focused, context .. ":FocusedElement"),
        DataContext = describeAction(dc, context .. ":FocusedDataContext"),
    }, dc
end

local function namedChildInfo(page, name, context)
    local child = safe(context .. ":Find(" .. name .. ")", function()
        return page:Find(name)
    end)
    if child == nil then
        return nil
    end

    local info = describeNodeShallow(child, context .. ":" .. name)
    info.ItemsCount = safe(context .. ":" .. name .. ":Items.Count", function()
        return child.Items.Count
    end, true)
    info.ItemsSourceCount = countOf(safe(context .. ":" .. name .. ":ItemsSource", function()
        return child.ItemsSource
    end, true))
    return info
end

local function describeDCHotBar(dc, focusedParameter, context, deep)
    if dc == nil then
        return nil
    end

    local info = {
        Type = objectType(dc),
        Values = simpleKnownProperties(dc, context),
        Commands = {},
    }

    local wasDCHotBarSeen = report.Summary.DCHotBarSeen
    if info.Type and string.lower(info.Type):find("dchotbar", 1, true) then
        report.Summary.DCHotBarSeen = true
    end

    if deep or not wasDCHotBarSeen then
        info.Properties, info.PropertiesTruncated = propertyNames(dc, context)
    end

    local commandNames = {
        "UseSlotCommand",
        "ClearSingleHotbarCommand",
        "CustomEvent",
        "ShowTooltipOnUIElement",
        "HideTooltipOnUIElement",
        "HighlightResourcesCommand",
        "ClearResourceHighlightsCommand",
        "CallAllies",
    }
    for _, name in ipairs(commandNames) do
        local value = safe(context .. ":command:" .. name, function()
            return dc[name]
        end, true)
        local command = commandInfo(value, focusedParameter, context .. ":command:" .. name)
        if command then
            info.Commands[name] = command
        end
    end

    local currentPlayer = safe(context .. ":CurrentPlayer", function()
        return dc.CurrentPlayer
    end)
    local selectedCharacter = currentPlayer and safe(context .. ":SelectedCharacter", function()
        return currentPlayer.SelectedCharacter
    end)

    if currentPlayer then
        info.CurrentPlayer = {
            Type = objectType(currentPlayer),
            Values = simpleKnownProperties(currentPlayer, context .. ":CurrentPlayer"),
        }
        local uiData = safe(context .. ":UIData", function()
            return currentPlayer.UIData
        end, true)
        if uiData then
            info.CurrentPlayer.UIData = {
                Type = objectType(uiData),
                Values = simpleKnownProperties(uiData, context .. ":UIData"),
            }
        end
    end

    if selectedCharacter then
        local groups = safe(context .. ":SpellsAndActions", function()
            return selectedCharacter.SpellsAndActions
        end)
        local hotbars = safe(context .. ":HotBars", function()
            return selectedCharacter.HotBars
        end)

        local groupsCount = countOf(groups)
        local hotbarsCount = countOf(hotbars)
        info.SpellsAndActions = { Count = groupsCount }
        info.HotBars = { Count = hotbarsCount }

        if groupsCount and groupsCount > 0 then
            report.Summary.ActionGroupsSeen = true
        end

        if deep then
            info.SpellsAndActions = collectionPreview(groups, context .. ":SpellsAndActions", describeActionGroup)
            info.HotBars = collectionPreview(hotbars, context .. ":HotBars", describeHotbar)
        end
    end

    local singleHotbar = safe(context .. ":SingleHotBar", function()
        return dc.SingleHotBar
    end, true)
    if singleHotbar then
        local slots = safe(context .. ":SingleHotBar.SlotList", function()
            return singleHotbar.SlotList
        end, true)
        local slotCount = countOf(slots)
        info.SingleHotBar = {
            Type = objectType(singleHotbar),
            SlotList = { Count = slotCount },
        }

        if slotCount and slotCount > 0 then
            local firstSeen = not report.Summary.SingleHotBarSeen
            report.Summary.SingleHotBarSeen = true
            if deep or firstSeen then
                info.SingleHotBar = describeHotbar(singleHotbar, context .. ":SingleHotBar")
            end
        end
    end

    return info
end
local function rootAndContent()
    local root = safe("Ext.UI.GetRoot", function()
        return Ext.UI.GetRoot()
    end)
    if not root then
        return nil, nil
    end

    local content = safe("root.Find(ContentRoot)", function()
        return root:Find("ContentRoot")
    end)
    return root, content
end

local function relevantScore(node)
    local name = string.lower(nodeName(node))
    local fileName = string.lower(nodeFileName(node))
    local runtimeType = string.lower(nodeType(node) or "")
    local score = 0

    if name == "cam_actionmenu" then score = score + 2000 end
    if fileName:find("cam_actionmenu", 1, true) then score = score + 2000 end
    if name:find("actionradial", 1, true) then score = score + 1400 end
    if fileName:find("actionradial", 1, true) then score = score + 1400 end
    if fileName:find("preloadedactionradials", 1, true) then score = score + 1600 end
    if name:find("radial", 1, true) then score = score + 500 end
    if fileName:find("radial", 1, true) then score = score + 500 end
    if name:find("hotbar", 1, true) then score = score + 250 end
    if fileName:find("hotbar", 1, true) then score = score + 250 end
    if runtimeType:find("radial", 1, true) then score = score + 250 end
    return score
end

local function scanRelevantNodes(content)
    local result = {}
    if not content then
        return result
    end

    local queue = {
        { Node = content, Depth = 0 },
    }
    local cursor = 1
    local visited = 0

    while cursor <= #queue and visited < MAX_SCAN_NODES do
        local entry = queue[cursor]
        cursor = cursor + 1
        visited = visited + 1

        local node = entry.Node
        local score = relevantScore(node)
        if score > 0 and #result < MAX_RELEVANT_NODES then
            local info = describeNodeShallow(node, "scan")
            info.Depth = entry.Depth
            info.Score = score
            result[#result + 1] = info
        end

        if entry.Depth < MAX_SCAN_DEPTH then
            local count = safe("VisualChildrenCount", function()
                return node.VisualChildrenCount
            end, true)
            if type(count) == "number" then
                for i = 1, count do
                    local child = safe("VisualChild(" .. i .. ")", function()
                        return node:VisualChild(i)
                    end, true)
                    if child then
                        queue[#queue + 1] = {
                            Node = child,
                            Depth = entry.Depth + 1,
                        }
                    end
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return (a.Score or 0) > (b.Score or 0)
    end)

    return result, visited
end

local function findPage(content, name)
    if not content then
        return nil
    end

    return safe("content.Find(" .. name .. ")", function()
        return content:Find(name)
    end)
end

local function persist()
    report.Environment.GameState = gameState()
    report.Summary.DiagnosticsCompleteEnough =
        report.Summary.CustomPageSeen
        and report.Summary.DCHotBarSeen
        and report.Summary.ActionGroupsSeen
        and report.Summary.FocusedActionSeen

    local json = safe("Ext.Json.Stringify", function()
        return Ext.Json.Stringify(report, {
            Beautify = true,
            StringifyInternalTypes = true,
        })
    end)

    if type(json) ~= "string" then
        json = safe("Ext.Json.Stringify:fallback", function()
            return Ext.Json.Stringify(report)
        end)
    end

    if type(json) == "string" then
        local ok = safe("Ext.IO.SaveFile", function()
            return Ext.IO.SaveFile(OUTPUT_FILE, json)
        end)
        if ok == false then
            recordError("Ext.IO.SaveFile", "SaveFile returned false")
        end
    end
end

local function capture(reason, forceScan)
    if #report.Snapshots >= MAX_SNAPSHOTS then
        return
    end

    local root, content = rootAndContent()
    local custom = findPage(content, "CAM_ActionMenu")
    local vanilla = findPage(content, "ActionRadials")

    local relevant = {}
    local visited = nil
    if forceScan or custom == nil then
        relevant, visited = scanRelevantNodes(content)
    end

    local firstCustomPage = custom ~= nil and not report.Summary.CustomPageSeen
    if custom ~= nil then
        report.Summary.CustomPageSeen = true
    end
    if vanilla ~= nil and custom == nil then
        report.Summary.VanillaRadialSeen = true
    end

    local page = custom or vanilla
    local focusedInfo, focusedParameter = describeFocused(page, "page")
    local dc = page and safe("page.DataContext", function()
        return page.DataContext
    end) or nil
    local deep = forceScan or firstCustomPage or not report.Summary.DCHotBarSeen

    local snapshot = {
        T = rawNow(),
        Reason = reason,
        GameState = gameState(),
        RootFound = root ~= nil,
        ContentRootFound = content ~= nil,
        CustomPage = describeNodeShallow(custom, "custom"),
        VanillaRadial = describeNodeShallow(vanilla, "vanilla"),
        RelevantNodes = relevant,
        ScannedNodes = visited,
        Focused = focusedInfo,
        DataContext = describeDCHotBar(dc, focusedParameter, "DCHotBar", deep),
        NamedElements = {},
    }

    if custom then
        local names = {
            "ActionGroups",
            "UtilityHotbars",
            "MainHotbarListHolder",
            "VariantHolder",
            "VariantList",
            "PanelTitle",
            "CancelButton",
        }
        for _, name in ipairs(names) do
            snapshot.NamedElements[name] = namedChildInfo(custom, name, "custom")
        end
    end

    report.Snapshots[#report.Snapshots + 1] = snapshot
    persist()
end

local function scheduleCapture(reason, delay, forceScan)
    Ext.Timer.WaitForRealtime(delay, function()
        capture(reason .. "+" .. tostring(delay) .. "ms", forceScan)
    end)
end

local function recordInput(event)
    if #report.Inputs >= MAX_INPUTS then
        return
    end

    report.Inputs[#report.Inputs + 1] = {
        T = rawNow(),
        DeviceId = stringify(safe("input.DeviceId", function() return event.DeviceId end)),
        Event = stringify(safe("input.Event", function() return event.Event end)),
        Button = stringify(safe("input.Button", function() return event.Button end)),
        Pressed = safe("input.Pressed", function() return event.Pressed end),
    }
end

local function refreshEnvironment()
    report.Environment.Build = BUILD_ID
    report.Environment.GameVersion = stringify(safe("Ext.Utils.GameVersion", function()
        return Ext.Utils.GameVersion()
    end))
    report.Environment.ScriptExtenderVersion = safe("Ext.Utils.Version", function()
        return Ext.Utils.Version()
    end)
    report.Environment.GameState = gameState()
end

local function reset()
    pressedCount = 0
    report = {
        Build = BUILD_ID,
        Environment = {},
        Summary = {
            SessionLoaded = false,
            CustomPageSeen = false,
            VanillaRadialSeen = false,
            DCHotBarSeen = false,
            ActionGroupsSeen = false,
            FocusedActionSeen = false,
            SingleHotBarSeen = false,
            DiagnosticsCompleteEnough = false,
        },
        Inputs = {},
        Snapshots = {},
        Errors = {},
    }
    refreshEnvironment()
    persist()
    Ext.Log.Print("[BG3ControllerActionMenu] diagnostics reset")
end

local function status()
    persist()
    Ext.Log.Print(
        string.format(
            "[BG3ControllerActionMenu] diagnostics: custom=%s dchotbar=%s groups=%s focus=%s variants=%s snapshots=%d errors=%d",
            tostring(report.Summary.CustomPageSeen),
            tostring(report.Summary.DCHotBarSeen),
            tostring(report.Summary.ActionGroupsSeen),
            tostring(report.Summary.FocusedActionSeen),
            tostring(report.Summary.SingleHotBarSeen),
            #report.Snapshots,
            #report.Errors
        )
    )
end

function Diagnostics.Register(options)
    if registered then
        return
    end
    registered = true
    options = options or {}

    refreshEnvironment()
    persist()

    pcall(function()
        Ext.RegisterConsoleCommand("cam_diag", function()
            capture("manual", true)
            status()
        end)
        Ext.RegisterConsoleCommand("cam_diag_reset", reset)
        Ext.RegisterConsoleCommand("cam_diag_status", status)

        -- Backward-compatible aliases from the early probe builds.
        Ext.RegisterConsoleCommand("cam_probe", function()
            capture("manual-probe-alias", true)
            status()
        end)
        Ext.RegisterConsoleCommand("cam_probe_reset", reset)
    end)

    pcall(function()
        Ext.Events.SessionLoaded:Subscribe(function()
            report.Summary.SessionLoaded = true
            refreshEnvironment()
            persist()
            scheduleCapture("session-loaded", 750, true)
            scheduleCapture("session-loaded", 2500, true)
        end)
    end)

    pcall(function()
        Ext.Events.ControllerButtonInput:Subscribe(function(event)
            recordInput(event)

            local pressed = safe("ControllerButtonInput.Pressed", function()
                return event.Pressed
            end)

            if pressed == true and pressedCount < AUTO_PRESSED_LIMIT then
                pressedCount = pressedCount + 1
                local button = stringify(safe("ControllerButtonInput.Button", function()
                    return event.Button
                end)) or "unknown"
                local reason = "controller:" .. button .. ":" .. tostring(pressedCount)

                -- Immediate capture establishes pre-transition state; delayed captures
                -- catch state creation, focus movement, variant/upcast transitions and close.
                capture(reason .. "+0ms", not report.Summary.CustomPageSeen)
                scheduleCapture(reason, 90, not report.Summary.CustomPageSeen)
                scheduleCapture(reason, 320, false)
                scheduleCapture(reason, 850, false)
            else
                persist()
            end
        end)
    end)

    pcall(function()
        Ext.Events.ViewportResized:Subscribe(function(event)
            report.Environment.LastViewportResize = {
                T = rawNow(),
                Width = stringify(safe("ViewportResized.Width", function() return event.Width end, true)),
                Height = stringify(safe("ViewportResized.Height", function() return event.Height end, true)),
            }
            persist()
        end)
    end)

    Ext.Log.Print(
        "[BG3ControllerActionMenu] first-run diagnostics active; output: " .. OUTPUT_FILE
    )
end

return Diagnostics

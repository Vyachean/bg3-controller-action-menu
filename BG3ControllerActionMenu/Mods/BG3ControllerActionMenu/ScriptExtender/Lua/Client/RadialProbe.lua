local RadialProbe = {}

local OUTPUT_FILE = "BG3ControllerActionMenu/probe.json"
local BUILD_ID = "0.0.2-grid-prototype"
local MAX_DEPTH = 16
local MAX_NODES = 2500
local MAX_PROPERTIES = 300
local MAX_COLLECTION_PREVIEW = 4
local BURST_INTERVAL_MS = 100
local BURST_TRIES = 14

local records = {}
local seenSignatures = {}
local burstGeneration = 0
local registered = false

local function safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function gameState()
    local state = safe(Ext.Utils.GetGameState)
    return state and tostring(state) or "Unknown"
end

local function scanAllowed()
    local state = gameState()
    return state == "Running" or state == "Paused"
end

local function objectType(value)
    local luaType = type(value)
    if luaType ~= "userdata" then
        return luaType
    end

    local noesisType = safe(function()
        return value.Type
    end)
    if noesisType ~= nil then
        return tostring(noesisType)
    end

    return "userdata"
end

local function nodeName(node)
    local name = safe(function()
        return node.Name
    end)
    return name and tostring(name) or ""
end

local function nodeFileName(node)
    local fileName = safe(function()
        return node.FileName
    end)
    return fileName and tostring(fileName) or ""
end

local function nodeRuntimeType(node)
    local runtimeType = safe(function()
        return node.Type
    end)
    return runtimeType and tostring(runtimeType) or ""
end

local function visualChildCount(node)
    local count = safe(function()
        return node.VisualChildrenCount
    end)
    return type(count) == "number" and count or 0
end

local function visualChild(node, index)
    return safe(function()
        return node:VisualChild(index)
    end)
end

local function contentRoot()
    local root = safe(Ext.UI.GetRoot)
    if not root then
        return nil
    end
    return safe(function()
        return root:Find("ContentRoot")
    end)
end

local function lower(value)
    return string.lower(value or "")
end

local function candidateScore(name, fileName, runtimeType)
    local score = 0
    local n = lower(name)
    local f = lower(fileName)
    local t = lower(runtimeType)

    if f:find("preloadedactionradials", 1, true) then
        score = score + 1000
    end
    if n:find("radial", 1, true) then
        score = score + 300
    end
    if f:find("radial", 1, true) then
        score = score + 300
    end
    if t:find("radial", 1, true) then
        score = score + 200
    end
    if n:find("action", 1, true) then
        score = score + 50
    end
    if f:find("action", 1, true) then
        score = score + 50
    end

    return score
end

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

local function propertyBag(object)
    local props = safe(function()
        return object:GetAllProperties()
    end)
    return type(props) == "table" and props or nil
end

local function collectionPreview(value)
    local count = safe(function()
        return #value
    end)

    if type(count) ~= "number" or count <= 0 then
        count = safe(function()
            return value.Count
        end)
    end

    local result = {
        Count = type(count) == "number" and count or nil,
        Items = {},
    }

    if type(count) ~= "number" then
        return result
    end

    local limit = math.min(count, MAX_COLLECTION_PREVIEW)
    for i = 1, limit do
        local item = safe(function()
            return value[i]
        end)
        if item ~= nil then
            local itemInfo = {
                Index = i,
                Type = objectType(item),
            }
            local itemProps = propertyBag(item)
            if itemProps then
                itemInfo.Properties = sortedKeys(itemProps)
            end
            result.Items[#result.Items + 1] = itemInfo
        end
    end

    return result
end

local function inspectDataContext(node)
    local dc = safe(function()
        return node.DataContext
    end)

    if not dc then
        return nil
    end

    local info = {
        Type = objectType(dc),
        Properties = {},
        Commands = {},
        Collections = {},
    }

    local props = propertyBag(dc)
    if not props then
        return info
    end

    local keys = sortedKeys(props)
    for i, key in ipairs(keys) do
        if i > MAX_PROPERTIES then
            info.Truncated = true
            break
        end

        local value = props[key]
        local kind = objectType(value)
        info.Properties[#info.Properties + 1] = {
            Name = key,
            Type = kind,
        }

        local canExecute = safe(function()
            return value.CanExecute
        end)
        local execute = safe(function()
            return value.Execute
        end)
        if canExecute ~= nil and execute ~= nil then
            info.Commands[#info.Commands + 1] = key
        end

        local preview = collectionPreview(value)
        if preview.Count ~= nil then
            info.Collections[key] = preview
        end
    end

    return info
end

local function signatureOf(candidate)
    return table.concat({
        candidate.Name or "",
        candidate.FileName or "",
        candidate.RuntimeType or "",
        candidate.DataContext and candidate.DataContext.Type or "",
    }, "|")
end

local function persist()
    local payload = {
        Build = BUILD_ID,
        GameState = gameState(),
        Captures = records,
    }

    local json = safe(function()
        return Ext.Json.Stringify(payload, {
            Beautify = true,
            StringifyInternalTypes = true,
        })
    end)

    if type(json) ~= "string" then
        json = safe(function()
            return Ext.Json.Stringify(payload)
        end)
    end

    if type(json) == "string" then
        safe(Ext.IO.SaveFile, OUTPUT_FILE, json)
    end
end

local function inspectCandidate(node, depth, score)
    local candidate = {
        Depth = depth,
        Score = score,
        Name = nodeName(node),
        FileName = nodeFileName(node),
        RuntimeType = nodeRuntimeType(node),
        DataContext = inspectDataContext(node),
    }

    local signature = signatureOf(candidate)
    if seenSignatures[signature] then
        return false
    end

    seenSignatures[signature] = true
    records[#records + 1] = candidate
    persist()

    Ext.Utils.Print(
        string.format(
            "[BG3ControllerActionMenu] radial candidate captured: name=%s file=%s type=%s score=%d",
            candidate.Name,
            candidate.FileName,
            candidate.RuntimeType,
            score
        )
    )
    return true
end

local function scanOnce()
    if not scanAllowed() then
        return false
    end

    local root = contentRoot()
    if not root then
        return false
    end

    local queue = {
        { Node = root, Depth = 0 },
    }
    local cursor = 1
    local visited = 0
    local captured = false

    while cursor <= #queue and visited < MAX_NODES do
        local entry = queue[cursor]
        cursor = cursor + 1
        visited = visited + 1

        local node = entry.Node
        local depth = entry.Depth
        local name = nodeName(node)
        local fileName = nodeFileName(node)
        local runtimeType = nodeRuntimeType(node)
        local score = candidateScore(name, fileName, runtimeType)

        if score >= 200 then
            if inspectCandidate(node, depth, score) then
                captured = true
            end
        end

        if depth < MAX_DEPTH then
            local count = visualChildCount(node)
            for i = 1, count do
                local child = visualChild(node, i)
                if child then
                    queue[#queue + 1] = {
                        Node = child,
                        Depth = depth + 1,
                    }
                end
            end
        end
    end

    return captured
end

local function startBurst()
    burstGeneration = burstGeneration + 1
    local generation = burstGeneration

    local function pass(remaining)
        if generation ~= burstGeneration or remaining <= 0 then
            return
        end

        if scanOnce() then
            return
        end

        Ext.Timer.WaitForRealtime(BURST_INTERVAL_MS, function()
            pass(remaining - 1)
        end)
    end

    pass(BURST_TRIES)
end

local function resetProbe()
    records = {}
    seenSignatures = {}
    persist()
    Ext.Utils.Print("[BG3ControllerActionMenu] probe log reset")
end

function RadialProbe.Register(options)
    if registered then
        return
    end
    registered = true
    options = options or {}
    local auto = options.Auto ~= false

    persist()

    pcall(function()
        Ext.RegisterConsoleCommand("cam_probe", startBurst)
    end)
    pcall(function()
        Ext.RegisterConsoleCommand("cam_probe_reset", resetProbe)
    end)

    if auto then
        pcall(function()
            Ext.Events.ControllerButtonInput:Subscribe(function()
                startBurst()
            end)
        end)

        pcall(function()
            Ext.Events.SessionLoaded:Subscribe(function()
                burstGeneration = burstGeneration + 1
                Ext.Timer.WaitForRealtime(1000, startBurst)
            end)
        end)
    end

    Ext.Utils.Print(
        "[BG3ControllerActionMenu] radial probe registered; use !cam_probe when diagnostics are needed"
    )
end

return RadialProbe

-- Squad Status HUD, 1.1.1. Made with AI by NEXara.
-- Reads the player's real squad. No gameplay values are written.
local directory = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local config = dofile(directory .. "config.lua")
local Alerts = dofile(directory .. "alerts.lua")
local alertTracker = Alerts.new(config)
local state = { host = nil, player = nil, canvas = nil, rows = {}, alertWidgets = {}, alertEvents = {}, clock = os.time(), scanAt = 0, faults = 0, lastReport = "", reportAt = 0 }
local messages = { en = { squad = "SQUAD", unknown = "Unknown", health = "HP", empty = "No squad members", unavailable = "HP unavailable", joined = "Joined squad: ", died = "Trooper lost: " },
                   th = { squad = "ทีม", unknown = "ไม่ทราบชื่อ", health = "พลังชีวิต", empty = "ยังไม่มีสมาชิกทีม", unavailable = "ยังอ่านพลังชีวิตไม่ได้", joined = "เข้าร่วมทีม: ", died = "เสียชีวิต: " } }
local text = messages[config.Language] or messages.en
local function log(value) print("[SquadStatusHUD] " .. tostring(value) .. "\n") end
local function report(value)
    if value ~= state.lastReport or os.time() >= state.reportAt then
        log(value)
        state.lastReport, state.reportAt = value, os.time() + 15
    end
end
local function valid(object)
    if object == nil then return false end
    local ok, result = pcall(function() return object:IsValid() end)
    return ok and result
end
-- The enemy nameplate font can be unavailable when this HUD first attaches.
-- Never leave Thai notices on TextBlock's default Latin-only fallback font.
local thaiFont, thaiFontChecked
local function noticeFont()
    if config.Language ~= "th" then return nil end
    if not thaiFontChecked then
        thaiFontChecked = true
        local path = "/Game/UI/Font/Noto_Sans/static/NotoSans-Medium_Font.NotoSans-Medium_Font"
        thaiFont = StaticFindObject(path)
        if not valid(thaiFont) and LoadAsset then
            local ok, loaded = pcall(LoadAsset, path)
            if ok then thaiFont = loaded end
        end
    end
    return valid(thaiFont) and thaiFont or nil
end
local function property(object, name)
    local ok, result = pcall(function() return object[name] end)
    if ok then return result end
    return nil
end
local function toString(value)
    if type(value) == "string" then return value end
    if value == nil then return "" end
    local ok, result = pcall(function() return value:ToString() end)
    return ok and result or ""
end
local function hide()
    for _, widget in ipairs(state.alertWidgets) do
        if valid(widget) then widget:SetVisibility(1) end
    end
    for _, row in ipairs(state.rows) do
        for _, widget in ipairs(row.widgets) do
            if valid(widget) then widget:SetVisibility(1) end -- Collapsed
        end
    end
end
local function clear()
    for _, widget in ipairs(state.alertWidgets) do
        if valid(widget) then pcall(function() widget:RemoveFromParent() end) end
    end
    state.alertWidgets, state.alertEvents = {}, {}
    alertTracker:reset()
    for _, row in ipairs(state.rows) do
        for _, widget in ipairs(row.widgets) do
            if valid(widget) then pcall(function() widget:RemoveFromParent() end) end
        end
    end
    state.rows = {}
    state.host, state.player, state.canvas, state.styleSource = nil, nil, nil, nil
end
local function findPlayer(host)
    local controller = host:GetOwningPlayer()
    if not valid(controller) then return nil end
    local pawn = controller:K2_GetPawn()
    if valid(pawn) and valid(property(pawn, "SquadLeaderComponent")) then return pawn end
    return nil
end
local function visible(host)
    local ok, shown = pcall(function() return host:IsVisible() end)
    return ok and shown
end
local function acquire()
    if valid(state.host) and valid(state.canvas) and visible(state.host) then
        local player = findPlayer(state.host)
        if valid(player) then
            local same = state.player == player
            pcall(function() same = state.player:GetFullName() == player:GetFullName() end)
            if not same then clear(); state.scanAt = 0 else state.player = player; return true end
        end
    end
    if state.host ~= nil then clear() end
    -- Discovery is throttled; never enumerate all actors every refresh.
    if os.time() < state.scanAt then return false end
    state.scanAt = os.time() + 3
    local hosts = FindAllOf("WB_Gameplay_Persistent_UI_C") or {}
    -- Prefer the live viewport widget; a retained lobby/old-map widget can have
    -- a valid controller even though it will never paint the new roster.
    for pass = 1, 2 do
      for _, host in ipairs(hosts) do
        local inViewport = false
        if valid(host) then pcall(function() inViewport = host:IsInViewport() end) end
        if valid(host) and visible(host) and (pass == 2 or inViewport) then
            local player = findPlayer(host)
            local canvas = property(host, "Base_Canvas_Panel")
            if valid(player) and valid(canvas) then
                state.host, state.player, state.canvas = host, player, canvas
                local trooper = property(host, "TrooperHUD")
                state.styleSource = valid(trooper) and property(trooper, "WB_Enemy_Health") or nil
                if not valid(state.styleSource) then
                    for _, candidate in ipairs(FindAllOf("WB_Enemy_Health_C") or {}) do
                        if valid(candidate) and candidate:GetOwningPlayer() == host:GetOwningPlayer() then
                            state.styleSource = candidate
                            break
                        end
                    end
                end
                log("Attached to " .. host:GetFullName() .. "; inViewport=" .. tostring(inViewport))
                return true
            end
        end
      end
    end
    report("Waiting for visible gameplay HUD; candidates=" .. tostring(#hosts))
    return false
end
local function addWidget(className, x, y, width, height, z, initialize)
    local class = StaticFindObject("/Script/UMG." .. className)
    assert(valid(class), "Missing UMG class " .. className)
    local tree = state.host.WidgetTree
    assert(valid(tree), "HUD WidgetTree unavailable")
    local widget = StaticConstructObject(class, tree)
    assert(valid(widget), "Could not construct " .. className)
    -- Apply style before AddChild constructs its underlying Slate widget.
    if initialize then
        local ok, err = pcall(initialize, widget)
        if not ok then log("Style fallback: " .. tostring(err)) end
    end
    local slot = state.canvas:AddChildToCanvas(widget)
    assert(valid(slot), "Could not attach HUD widget")
    slot:SetAnchors({ Minimum = { X = 0, Y = 1 }, Maximum = { X = 0, Y = 1 } })
    slot:SetAlignment({ X = 0, Y = 0 })
    slot:SetPosition({ X = x, Y = y })
    slot:SetSize({ X = width, Y = height })
    slot:SetZOrder(z or 50)
    widget:SetVisibility(3) -- HitTestInvisible: never intercept gameplay input.
    return widget
end
local function rowAt(index, count)
    local scale = math.max(0.5, math.min(4, tonumber(config.Scale) or 2))
    local y = -config.Bottom - ((count or config.MaxRows) - index + 1) * config.RowHeight * scale
    if state.rows[index] then
        local row = state.rows[index]
        row.frame.Slot:SetPosition({ X = config.Left, Y = y })
        row.bar.Slot:SetPosition({ X = config.Left + 12 * scale, Y = y + 6 * scale })
        row.label.Slot:SetPosition({ X = config.Left + 10 * scale, Y = y + 3 * scale })
        return row
    end
    local row = { widgets = {} }
    -- Register each widget immediately, so a partial construction failure can clean it up.
    state.rows[index] = row
    local source = state.styleSource
    local originalBar = valid(source) and property(source, "Enemy_Health_Progress_Bar") or nil
    local originalFrame = valid(source) and property(source, "Health_Frame") or nil
    local originalText = valid(source) and property(source, "Enemy_Name_Text") or nil
    local brush = valid(originalFrame) and property(originalFrame, "Brush") or nil
    if brush then
        row.frame = addWidget("Image", config.Left, y, config.Width * scale, 28 * scale, 49,
            function(widget) widget:SetBrush(brush) end)
    else
        row.frame = addWidget("Border", config.Left, y, config.Width * scale, 28 * scale, 49,
            function(widget) widget:SetBrushColor({ R = 0.025, G = 0.06, B = 0.15, A = 0.92 }) end)
    end
    table.insert(row.widgets, row.frame)
    -- The native frame texture has transparent padding around its visible rim.
    -- Keep the fill inside that rim, not just inside the image rectangle.
    row.bar = addWidget("ProgressBar", config.Left + 12 * scale, y + 6 * scale,
        (config.Width - 24) * scale, 16 * scale, 50, function(widget)
            if valid(originalBar) then widget.WidgetStyle = originalBar.WidgetStyle end
        end)
    table.insert(row.widgets, row.bar)
    row.bar:SetFillColorAndOpacity({ R = 0.15, G = 0.45, B = 0.95, A = 1 })
    row.label = addWidget("TextBlock", config.Left + 10 * scale, y + 3 * scale,
        (config.Width - 20) * scale, 23 * scale, 52, function(widget)
            if valid(originalText) then widget.Font = originalText.Font end
        end)
    table.insert(row.widgets, row.label)
    local font = row.label.Font
    font.Size = math.floor(config.FontSize * scale + 0.5)
    row.label:SetFont(font)
    row.label:SetColorAndOpacity({ SpecifiedColor = { R = 0.94, G = 0.97, B = 1, A = 1 }, ColorUseRule = 0 })
    log("Created blue nameplate; nativeBar=" .. tostring(valid(originalBar)) .. "; nativeFrame=" .. tostring(brush ~= nil))
    return row
end
local function liveHealth(actor)
    local component = property(actor, "HealthComponent")
    if not valid(component) then
        local class = StaticFindObject("/Script/ADGASHealth.ADHealthComponent")
        if valid(class) then
            local ok, result = pcall(function() return actor:GetComponentByClass(class) end)
            if ok then component = result end
        end
    end
    if not valid(component) then return nil, nil, "no live health component" end
    local ok, current, maximum = pcall(function()
        return component:GetCurrentHealth(), component:GetMaxHealth()
    end)
    if not ok then return nil, nil, tostring(current) end
    current, maximum = tonumber(current), tonumber(maximum)
    if not current or not maximum or current ~= current or maximum ~= maximum
        or current == math.huge or maximum == math.huge or maximum <= 0 then
        return nil, nil, "invalid live health values"
    end
    return current, maximum, "ADHealthComponent"
end
local function readSquad()
    local leader = state.player.SquadLeaderComponent
    local members = leader.SquadMembers
    assert(members ~= nil, "SquadMembers is unavailable")
    local roster, details = {}, {}
    members:ForEach(function(_, element)
        local actor = element:get()
        if valid(actor) and #roster < config.MaxRows then
            -- NPC.CurrentHealth/MaxHealth were observed stuck at 0/25 in-game.
            -- Read the GAS health component, the same getters used by the native HUD.
            local health, maximum, healthSource = liveHealth(actor)
            -- Missing/invalid values must never be displayed as invented health.
            do
                local name = toString(property(actor, "NameInSquad"))
                if name == "" or name == "None" then
                    local ok, result = pcall(function() return actor:GetActorName() end)
                    if ok then name = toString(result) end
                end
                if name == "" then name = text.unknown end
                local known = health ~= nil and maximum ~= nil and maximum > 0
                local key = tostring(actor)
                pcall(function() key = actor:GetFullName() end)
                roster[#roster + 1] = { key = key, actor = actor, name = name, hp = health, max = maximum, known = known }
                details[#details + 1] = name .. ":" .. tostring(health) .. "/" .. tostring(maximum) .. " [" .. healthSource .. "]"
            end
        end
    end)
    return roster, "members=" .. tostring(#members) .. "; rows=" .. tostring(#roster) .. "; " .. table.concat(details, ", ")
end
local function renderAlerts(events, rosterCount)
    state.alertEvents = events
    local scale = math.max(0.5, math.min(4, tonumber(config.Scale) or 2))
    local bottom = tonumber(config.AlertBottom) or (config.Bottom + rosterCount * config.RowHeight * scale + 24)
    for index, event in ipairs(events) do
        local widget = state.alertWidgets[index]
        if not valid(widget) then
            widget = addWidget("TextBlock", config.Left + 10 * scale, 0,
                config.Width * scale, 60 * scale, 53, function(label)
                    local source = valid(state.styleSource) and property(state.styleSource, "Enemy_Name_Text") or nil
                    if valid(source) then label.Font = source.Font end
                end)
            state.alertWidgets[index] = widget
            local font = widget.Font
            local thai = noticeFont()
            if thai then
                font.FontObject = thai
                font.TypefaceFontName = FName("Default")
            end
            font.Size = math.floor((tonumber(config.AlertFontSize) or 13) * scale + 0.5)
            widget:SetFont(font)
            widget:SetAutoWrapText(true)
            widget:SetShadowColorAndOpacity({ R = 0, G = 0, B = 0, A = 1 })
            widget:SetShadowOffset({ X = 1, Y = 1 })
        end
        local color = event.kind == "died" and { R = 1, G = 0.35, B = 0.3, A = 1 }
            or { R = 0.55, G = 0.85, B = 1, A = 1 }
        widget:SetColorAndOpacity({ SpecifiedColor = color, ColorUseRule = 0 })
        widget.Slot:SetPosition({ X = config.Left + 10 * scale, Y = -bottom - (#events - index + 1) * 62 * scale })
        widget:SetText(FText((text[event.kind] or "") .. event.name))
        widget:SetVisibility(3)
    end
end
local function confirmedDeath(actor)
    if not valid(actor) then return false end
    local hp = liveHealth(actor)
    return hp ~= nil and hp <= 0
end
local function update()
    if not acquire() then return end
    local roster, summary = readSquad()
    local controller = state.host:GetOwningPlayer()
    local hud = valid(controller) and controller:GetHUD() or nil
    if valid(hud) then
        local ok, uiMode = pcall(function() return hud:IsUIMode() end)
        if ok and uiMode then
            alertTracker:update(roster, math.max(state.clock, os.time()), true)
            report("Hidden in UI mode; " .. summary); hide(); return
        end
    end
    report("HUD active; " .. summary)
    hide()
    state.clock = math.max(state.clock, os.time())
    local events = alertTracker:update(roster, state.clock, false, confirmedDeath)
    renderAlerts(events, #roster)
    if #roster == 0 and config.ShowEmptyStatus then
        local row = rowAt(1, 1)
        row.label:SetText(FText(text.squad .. " — " .. text.empty))
        row.label:SetVisibility(3)
        row.frame:SetVisibility(1)
        row.bar:SetVisibility(1)
        return
    end
    for index, member in ipairs(roster) do
        local row = rowAt(index, #roster)
        for _, widget in ipairs(row.widgets) do widget:SetVisibility(3) end
        row.joinedAt, row.diedAt = nil, nil
        for _, event in ipairs(events) do
            if event.key == member.key then
                if event.kind == "joined" then row.joinedAt = event.started end
                if event.kind == "died" then row.diedAt = event.started end
            end
        end
        row.ratio = member.known and math.max(0, math.min(1, member.hp / member.max)) or nil
        row.label:SetText(FText(member.name))
        row.label:SetColorAndOpacity({SpecifiedColor = row.ratio == 0
            and {R=1,G=0.4,B=0.35,A=1} or {R=0.94,G=0.97,B=1,A=1}, ColorUseRule=0})
        if member.known then
            local ratio = math.max(0, math.min(1, member.hp / member.max))
            local threshold = math.max(0.01, math.min(0.9, tonumber(config.LowHealthThreshold) or 0.30))
            row.bar:SetPercent(ratio)
            row.bar:SetFillColorAndOpacity(ratio <= threshold
                and { R = 1, G = 0.15, B = 0.12, A = 1 }
                or { R = 0.15, G = 0.45, B = 0.95, A = 1 })
        else
            row.bar:SetVisibility(1)
        end
    end
end
local function animate()
    state.clock = math.max(state.clock + 0.05, os.time())
    -- This loop only paints existing widgets. Squad/health discovery stays at 250 ms.
    for _, row in ipairs(state.rows) do
        local opacity = row.joinedAt and (0.55 + 0.45 * math.min(1, math.max(0, state.clock-row.joinedAt)/0.65)) or 1
        if row.ratio == 0 then
            local age = row.diedAt and state.clock-row.diedAt or 2
            opacity = age < 1.8 and (0.65 + 0.35 * (0.5 + 0.5 * math.cos(age*math.pi*2/0.9))) or 0.6
        end
        if valid(row.frame) then row.frame:SetRenderOpacity(opacity) end
        if valid(row.label) then row.label:SetRenderOpacity(opacity) end
        if valid(row.bar) then row.bar:SetRenderOpacity(opacity * Alerts.healthOpacity(row.ratio,state.clock)) end
    end
    for index, widget in ipairs(state.alertWidgets) do
        local event = state.alertEvents[index]
        if event and valid(widget) then
            local opacity, offset = Alerts.visual(event,state.clock)
            widget:SetRenderOpacity(opacity)
            widget:SetRenderTranslation({X=offset,Y=0})
        end
    end
end
assert(type(LoopInGameThreadWithDelay) == "function", "Squad Status HUD requires UE4SS 4.x")
log("1.1.0 loaded; language=" .. config.Language .. "; awaiting gameplay")
state.loop = LoopInGameThreadWithDelay(config.RefreshMs, function()
    local ok, err = pcall(update)
    if not ok then
        state.faults = state.faults + 1
        if state.faults <= 5 then log("Runtime check: " .. tostring(err)) end
        clear()
        state.scanAt = os.time() + 5
    else
        state.faults = 0
    end
end)

state.animationLoop = LoopInGameThreadWithDelay(50, function()
    local ok, err = pcall(animate)
    if not ok and not state.animationWarning then
        state.animationWarning = true
        log("Animation unavailable; roster remains active: " .. tostring(err))
    end
end)

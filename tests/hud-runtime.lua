-- Isolated behavioral regression harness. No Unreal process or game files.
local assertions = 0
function expect(value, message)
    assertions = assertions + 1
    if not value then error(message) end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
function object(value)
    value = value or {}
    function value:IsValid() return not self.destroyed end
    return value
end
logs, widgets = {}, {}
local clock = 100
os.time = function() return clock end
print = function(message) logs[#logs + 1] = tostring(message) end
debug.getinfo = function() return { source = "@fixture/main.lua" } end
dofile = function(path) if path:match("alerts.lua$") then return __alerts end; return __config end
FText = function(value) return value end
local function slot()
    local result = object()
    for _, name in ipairs({"Anchors", "Alignment", "Position", "Size", "ZOrder"}) do
        result["Set" .. name] = function(self, value) self[name] = copy(value) end
    end
    return result
end
function StaticFindObject(path) return object({ kind = path:match("%.([^%.]+)$") }) end
function StaticConstructObject(class, tree)
    local fields = { Font = { Size = 15 }, kind = class.kind, outer = tree }
    local methods = {}
    function methods:IsValid() return not fields.destroyed end
    function methods:RemoveFromParent() fields.destroyed = true end
    for _, name in ipairs({"Visibility", "Brush", "BrushColor", "Font", "ColorAndOpacity", "FillColorAndOpacity", "Percent", "Text", "AutoWrapText", "ShadowColorAndOpacity", "ShadowOffset", "RenderOpacity", "RenderTranslation"}) do
        methods["Set" .. name] = function(_, value) fields[name] = copy(value) end
    end
    local widget = setmetatable({}, {
        __index = function(_, key) return methods[key] or fields[key] end,
        __newindex = function(_, key, value) fields[key] = copy(value) end,
    })
    widgets[#widgets + 1] = widget
    return widget
end
canvas = object()
function canvas:AddChildToCanvas(widget) widget.Slot = slot(); return widget.Slot end
sourceText = object({ Font = { Size = 13 } })
sourceStyle = object({
    Enemy_Health_Progress_Bar = object({ WidgetStyle = { marker = "native health style" } }),
    Health_Frame = object({ Brush = { marker = "native frame" } }),
    Enemy_Name_Text = sourceText,
})
function member(name, hp, max)
    local health = object({ hp = hp, maximum = max })
    function health:GetCurrentHealth() return self.hp end
    function health:GetMaxHealth() return self.maximum end
    local actor = object({ NameInSquad = name, CurrentHealth = 0, MaxHealth = 25, HealthComponent = health })
    function actor:GetComponentByClass() return self.HealthComponent end
    return actor
end
members = { member("Pvt. Avery Hall", 75, 100), member("Cpl. Dana Frost", 40, 200) }
function members:ForEach(callback)
    for index, actor in ipairs(self) do callback(index, { get = function() return actor end }) end
end
player = object({ SquadLeaderComponent = object({ SquadMembers = members }) })
hud = object({ uiMode = false })
function hud:IsUIMode() return self.uiMode end
controller = object()
function controller:K2_GetPawn() return player end
function controller:GetHUD() return hud end
host = object({ Base_Canvas_Panel = canvas, WidgetTree = object(), TrooperHUD = object({ WB_Enemy_Health = sourceStyle }) })
function host:GetOwningPlayer() return controller end
function host:IsVisible() return true end
function host:IsInViewport() return true end
function host:GetFullName() return "Fixture gameplay HUD" end
function FindAllOf(class)
    if class == "WB_Gameplay_Persistent_UI_C" then return { host } end
    return {}
end
function LoopInGameThreadWithDelay(ms, callback) if ms == 50 then animationTick = callback else tick = callback end; return 1 end
function verify()
    tick()
    local bars, labels, frames = {}, {}, {}
    for _, widget in ipairs(widgets) do
        if widget.kind == "ProgressBar" then bars[#bars + 1] = widget end
        if widget.kind == "TextBlock" then labels[#labels + 1] = widget end
        if widget.kind == "Image" then frames[#frames + 1] = widget end
    end
    expect(#bars == 2 and #labels == 2, "roster contains actual two squad members")
    expect(bars[1].Percent == 0.75 and bars[2].Percent == 0.2, "live component health overrides stale NPC 0/25")
    expect(labels[1].Text == "Pvt. Avery Hall" and labels[2].Text == "Cpl. Dana Frost", "names only, no health numbers")
    expect(labels[1].Font.Size == 30, "font is twice the previous size")
    expect(frames[1].Slot.Size.X == 560 and frames[1].Slot.Size.Y == 56, "nameplate doubles width and height")
    expect(frames[2].Slot.Position.Y + frames[2].Slot.Size.Y <= -440, "roster stays above reserved score area")
    expect(bars[1].WidgetStyle.marker == "native health style", "reuses native health bar style")
    expect(frames[1].Brush.marker == "native frame", "reuses native game frame")
    expect(bars[1].FillColorAndOpacity.B == 0.95, "blue health fill")
    expect(sourceText.Font.Size == 13, "native HUD font remains unchanged")
    members[1].HealthComponent.hp = 25
    tick()
    expect(bars[1].Percent == 0.25, "health updates after damage")
    expect(bars[1].FillColorAndOpacity.R == 1, "low health changes bar to red")
    members[1].HealthComponent.hp = 31; tick()
    expect(bars[1].FillColorAndOpacity.B == 0.95, "recovery above threshold restores blue")
    members[1].HealthComponent.hp = 30; tick()
    expect(bars[1].FillColorAndOpacity.R == 1, "exactly 30 percent is red")
    members[1].HealthComponent = nil
    tick()
    expect(bars[1].Visibility == 1, "unavailable live health is not fabricated from stale fields")
    expect(labels[1].Text == "Pvt. Avery Hall", "unknown-health row still shows only name")
    hud.uiMode = true
    tick()
    expect(labels[1].Visibility == 1 and frames[1].Visibility == 1, "roster hides while menu is open")
    hud.uiMode = false
    members[#members + 1] = member("Pvt. Morgan Reed",100,100)
    clock = clock + 1
    tick()
    local function alertsWith(prefix)
        local result = {}
        for _, widget in ipairs(widgets) do
            if widget.kind == "TextBlock" and widget.Visibility == 3 and not widget.destroyed
                and widget.Text and widget.Text:sub(1,#prefix) == prefix then result[#result+1] = widget end
        end
        return result
    end
    expect(#alertsWith("Joined squad: ") == 1, "join notification renders in real widget update path")
    local joined = alertsWith("Joined squad: ")[1]
    animationTick()
    expect(joined.RenderOpacity > 0 and joined.RenderOpacity < 1, "new member notification fades in")
    expect(joined.RenderTranslation.X < 0, "join notice slides a few pixels")
    expect(joined.AutoWrapText and joined.ShadowColorAndOpacity.A == 1, "alert wraps long names and has a readable shadow")
    expect(joined.Slot.Position.Y + joined.Slot.Size.Y < -440 - #members * 68, "alerts sit above roster without covering nameplates")
    members[3].HealthComponent.hp = 20
    clock = clock + 1; tick()
    expect(#alertsWith("Low health: ") == 0, "low health never renders warning text")
    members[3].HealthComponent.hp = 0
    clock = clock + 1; tick()
    expect(#alertsWith("Trooper lost: ") == 1, "confirmed death renders notice")
    animationTick()
    expect(alertsWith("Trooper lost: ")[1].RenderOpacity > 0, "death emphasis stays visible")
    local deadLabel
    for _, widget in ipairs(widgets) do
        if widget.Text == "Pvt. Morgan Reed" and not widget.destroyed then deadLabel = widget end
    end
    expect(deadLabel and deadLabel.RenderOpacity >= 0.65 and deadLabel.ColorAndOpacity.SpecifiedColor.R == 1, "dead member nameplate briefly emphasizes red while still present")
    table.remove(members,3)
    clock = clock + 1; tick()
    expect(#alertsWith("Trooper lost: ") == 1, "removing a dead member does not duplicate notice")
    clock = clock + 10; tick()
    expect(#alertsWith("Joined squad: ") + #alertsWith("Low health: ") + #alertsWith("Trooper lost: ") == 0, "expired notification widgets are hidden")
    player = object({SquadLeaderComponent = object({SquadMembers = members})})
    clock = clock + 1; tick()
    expect(#alertsWith("Joined squad: ") == 0, "new pawn establishes silent squad baseline")
    expect(not table.concat(logs):find("Animation unavailable"), "animation uses supported widget methods")
    expect(not table.concat(logs):find("Runtime check:"), "no hidden UMG integration errors")
    return assertions
end

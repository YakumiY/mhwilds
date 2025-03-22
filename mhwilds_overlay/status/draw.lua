local re = re
local sdk = sdk
local d2d = d2d
local imgui = imgui
local log = log
local json = json
local draw = draw
local Vector3f = Vector3f
local require = require
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local math = math
local string = string
local table = table
local type = type
local _ = _

local Core = require("_CatLib")
local Debug = require("_CatLib.debug")
local Draw = require("_CatLib.draw")
local Div = require("_CatLib.div")
local CONST = require("_CatLib.const")


local mod = require("mhwilds_overlay.mod")
local OverlayData = require("mhwilds_overlay.data")
local Data = require("mhwilds_overlay.status.data")
local Config = require("mhwilds_overlay.status.conf")

local _M = {}

local CanvasRect = {
    Enable = true,
    OffsetX = 0,
    OffsetY = 100,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
}
local MergedBuffCanvas = Draw.NewDivCanvas(CanvasRect)

local SingleBuffCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 100,
    Width = 100,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})

local SkillBuffCanvas = Draw.NewDivCanvas(CanvasRect)
local MusicSkillBuffCanvas = Draw.NewDivCanvas(CanvasRect)
local OtomoSkillBuffCanvas = Draw.NewDivCanvas(CanvasRect)
local ItemBuffCanvas = Draw.NewDivCanvas(CanvasRect)
local ASkillBuffCanvas = Draw.NewDivCanvas(CanvasRect)
local WeaponBuffCanvas = Draw.NewDivCanvas(CanvasRect)

local PlayerStaminaCanvas = Draw.NewDivCanvas(CanvasRect)

---@param canvas DivCanvas
---@param text FontConfig
---@param ring CircleConfig
---@param data BuffStatus
---@param conf OverlayStatusSkillStatusConfig
---@param groupConf OverlayStatusGroupConfig
function _M.DrawBuff(canvas, text, ring, data, conf, groupConf)
    if data.Activated ~= true then -- data.Timer <= 0
        return nil
    end
    -- if data.Activated ~= true then
    --     return nil
    -- end

    local root = Div.new()
    root.height = "auto"
    root.width = 140

    if groupConf.ShowName then
        local nameDiv = Div.new()
        nameDiv.renderer = Draw.TextRenderer(text, tostring(data.Name))
        root:add(nameDiv)
    end

    local ratio = 0
    if data.Timer > 0 then
        ratio = data.Timer/data.MaxTimer
    end

    local ringDiv = Div.new()
    ringDiv.renderer = Draw.CircleRenderer(ring, ratio)
    root:add(ringDiv)

    if groupConf.ShowTime then
        local timerDiv = Div.new()
        timerDiv.renderer = Draw.TextRenderer(text, Core.GetTimeString(data.Timer))
        root:add(timerDiv)
    end
    
    -- local activated = Div.new()
    -- activated.renderer = Draw.TextRenderer(text, tostring(data.Activated))
    -- root:add(activated)
    return root
end

function _M.DrawBuffs()
    local WidgetConf = Config.BuffWidgetConfig
    if not WidgetConf.Enable then
        return
    end
    local skillCanvas, musicCanvas, otomoCanvas, itemCanvas, mantleCanvas, wpCanvas
    local skillDiv, musicDiv, otomoDiv, itemDiv, mantleDiv, wpDiv
    if WidgetConf.MergeAllBuffs then
        MergedBuffCanvas.Debug(mod.Config.Debug)
        MergedBuffCanvas.Init()
        MergedBuffCanvas.RePos(WidgetConf.OffsetX, WidgetConf.OffsetY)
        
        local mergedDiv = Div.new()
        mergedDiv.position.x = MergedBuffCanvas.PosX
        mergedDiv.position.y = MergedBuffCanvas.PosY
        mergedDiv.width = 1000
        mergedDiv.height = 200
        mergedDiv.display = "inline"
        
        skillCanvas, musicCanvas, otomoCanvas, itemCanvas, mantleCanvas, wpCanvas = MergedBuffCanvas, MergedBuffCanvas, MergedBuffCanvas, MergedBuffCanvas, MergedBuffCanvas, MergedBuffCanvas
        skillDiv, musicDiv, otomoDiv, itemDiv, mantleDiv, wpDiv = mergedDiv, mergedDiv, mergedDiv, mergedDiv, mergedDiv, mergedDiv
    else
        SkillBuffCanvas.Debug(mod.Config.Debug)
        SkillBuffCanvas.Init()
        skillCanvas = SkillBuffCanvas
        skillDiv = Div.new()
        skillDiv.position.x = skillCanvas.PosX
        skillDiv.position.y = skillCanvas.PosY
        skillDiv.width = 1000
        skillDiv.height = 200
        skillDiv.display = "inline"

        MusicSkillBuffCanvas.Debug(mod.Config.Debug)
        MusicSkillBuffCanvas.Init()
        musicCanvas = MusicSkillBuffCanvas
        musicDiv = Div.new()
        musicDiv.position.x = musicCanvas.PosX
        musicDiv.position.y = musicCanvas.PosY
        musicDiv.width = 1000
        musicDiv.height = 200
        musicDiv.display = "inline"

        OtomoSkillBuffCanvas.Debug(mod.Config.Debug)
        OtomoSkillBuffCanvas.Init()
        otomoCanvas = OtomoSkillBuffCanvas
        otomoDiv = Div.new()
        otomoDiv.position.x = otomoCanvas.PosX
        otomoDiv.position.y = otomoCanvas.PosY
        otomoDiv.width = 1000
        otomoDiv.height = 200
        otomoDiv.display = "inline"

        ItemBuffCanvas.Debug(mod.Config.Debug)
        ItemBuffCanvas.Init()
        itemCanvas = ItemBuffCanvas
        itemDiv = Div.new()
        itemDiv.position.x = itemCanvas.PosX
        itemDiv.position.y = itemCanvas.PosY
        itemDiv.width = 1000
        itemDiv.height = 200
        itemDiv.display = "inline"
    

        ASkillBuffCanvas.Debug(mod.Config.Debug)
        ASkillBuffCanvas.Init()
        mantleCanvas = ASkillBuffCanvas
        mantleDiv = Div.new()
        mantleDiv.position.x = mantleCanvas.PosX
        mantleDiv.position.y = mantleCanvas.PosY
        mantleDiv.width = 1000
        mantleDiv.height = 200
        mantleDiv.display = "inline"

        WeaponBuffCanvas.Debug(mod.Config.Debug)
        WeaponBuffCanvas.Init()
        wpCanvas = WeaponBuffCanvas
        wpDiv = Div.new()
        wpDiv.position.x = wpCanvas.PosX
        wpDiv.position.y = wpCanvas.PosY
        wpDiv.width = 1000
        wpDiv.height = 200
        wpDiv.display = "inline"
    end

    for key, data in pairs(Data.SkillData) do
        -- if not data.Name then
        --     Data.SkillData[key].Name = Core.GetSkillName(key)
        -- end

        local name = data.Name
        if data.BuffLevel then
            name = string.format("%s Lv%d", data.Name, data.BuffLevel)
        end

        local conf = Config.GetOrInitSkillConfig(key, name)
        if conf.Enable then
            local div = _M.DrawBuff(skillCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.SkillConfig)
            if div then
                skillDiv:add(div)
            end
        end
    end
    for key, data in pairs(Data.MuiscSkillData) do
        -- if not data.Name then
        --     Data.MuiscSkillData[key].Name = Core.GetMusicSkillName(key)
        -- end

        local conf = Config.GetOrInitMusicSkillConfig(key, data.Name)
        if conf.Enable then
            local div = _M.DrawBuff(musicCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.MusicSkillConfig)
            if div then
                musicDiv:add(div)
            end
        end
    end
    for key, data in pairs(Data.OtomoSkillData) do

        local conf = Config.GetOrInitOtomoSkillConfig(key, data.Name)
        if conf.Enable then
            local div = _M.DrawBuff(otomoCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.OtomoSkillConfig)
            if div then
                otomoDiv:add(div)
            end
        end
    end
    
    for key, data in pairs(Data.ItemBuffData) do
        -- if not data.Name then
        --     Data.ItemBuffData[key].Name = key
        -- end

        local conf = Config.GetOrInitItemConfig(key, data.Name)
        if conf.Enable then
            local div = _M.DrawBuff(itemCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.ItemBuffConfig)
            if div then
                itemDiv:add(div)
            end
        end
    end

    for key, data in pairs(Data.ASkillData) do
        -- if not data.Name then
        --     Data.ASkillData[key].Name = Core.GetASkillName(key)
        -- end

        local conf = Config.GetOrInitASkillConfig(key, data.Name)
        if conf.Enable then
            local div = _M.DrawBuff(mantleCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.ASkillConfig)
            if div then
                mantleDiv:add(div)
            end
        end
    end

    for key, data in pairs(Data.WeaponBuffData) do
        local conf = Config.GetOrInitWeaponConfig(key, data.Name)
        if conf.Enable then
            local div = _M.DrawBuff(wpCanvas, conf.Text, conf.Circle, data, conf, Config.BuffWidgetConfig.WeaponConfig)
            if div then
                wpDiv:add(div)
            end
        end
    end

    local debug = mod.Config.Debug
    if WidgetConf.MergeAllBuffs then
        MergedBuffCanvas.End()

        itemDiv:render(itemCanvas.PosX, itemCanvas.PosY, itemCanvas.Width, itemCanvas.Height, debug)
    else
        SkillBuffCanvas.End()
        MusicSkillBuffCanvas.End()
        OtomoSkillBuffCanvas.End()
        ItemBuffCanvas.End()
        ASkillBuffCanvas.End()
        
        skillDiv:render(skillCanvas.PosX, skillCanvas.PosY, skillCanvas.Width, skillCanvas.Height, debug)
        musicDiv:render(musicCanvas.PosX, musicCanvas.PosY, musicCanvas.Width, musicCanvas.Height, debug)
        otomoDiv:render(otomoCanvas.PosX, otomoCanvas.PosY, otomoCanvas.Width, otomoCanvas.Height, debug)
        itemDiv:render(itemCanvas.PosX, itemCanvas.PosY, itemCanvas.Width, itemCanvas.Height, debug)
        mantleDiv:render(mantleCanvas.PosX, mantleCanvas.PosY, mantleCanvas.Width, mantleCanvas.Height, debug)
        wpDiv:render(wpCanvas.PosX, wpCanvas.PosY, wpCanvas.Width, wpCanvas.Height, debug)
    end
end

local function NewStaminaCache()
    return {
        LastNonFillTime = 0,
        
        peakRatio = 0,
        lastRatio = 1,
        lastHitTimestamp = -1,
        redRatio = 0,
        initialRedRatio = 0,  -- 消逝过程中，初始的 red ratio
        fadeStartTimestampe = nil, -- 消逝起始时间
    
        currentSegIndex = nil,
    }
end

local StaminaCache = NewStaminaCache()

function _M.ClearCache()
    StaminaCache = NewStaminaCache()
end
    
---@param conf OverlayStatusHunterStaminaConfig
local function UpdateUsedStamina(current, max, segIndex, conf)
    if not conf.ShowUsedStamina then
        return
    end

    local ratio = current / max

    -- 百分比变多了
    if ratio > StaminaCache.lastRatio and StaminaCache.redRatio > 0 then
        -- StaminaCache.redRatio = 1 - ratio
        -- StaminaCache.initialRedRatio = StaminaCache.redRatio
        local delta = (ratio-StaminaCache.lastRatio)
        StaminaCache.initialRedRatio = StaminaCache.initialRedRatio - delta
        StaminaCache.redRatio = StaminaCache.redRatio - delta
    end

    -- if ratio > StaminaCache.peakRatio then
    --     StaminaCache.peakRatio = ratio
    -- end
    local simTime = OverlayData.SimulatedTime

    if conf.Segmented then
        if StaminaCache.currentSegIndex == nil then
            StaminaCache.currentSegIndex = segIndex
            StaminaCache.lastRatio = ratio
        end
        if segIndex ~= StaminaCache.currentSegIndex then
            if segIndex < StaminaCache.currentSegIndex then
                -- 消耗
                StaminaCache.redRatio = 1 - ratio
                StaminaCache.initialRedRatio = StaminaCache.redRatio
                StaminaCache.lastHitTimestamp = simTime
            else
                -- 恢复
                StaminaCache.redRatio = 0
                StaminaCache.initialRedRatio = 0
                StaminaCache.lastRatio = ratio
            end
            StaminaCache.currentSegIndex = segIndex
        end            
    end

    StaminaCache.lastTime = simTime

    if ratio < StaminaCache.lastRatio then
        -- if StaminaCache.fadeStartTimestampe == nil then
            StaminaCache.redRatio = StaminaCache.lastRatio - ratio + StaminaCache.redRatio
        -- else
        --     -- 衰减中，则直接清空
        --     StaminaCache.redRatio = StaminaCache.lastRatio - ratio
        -- end
        StaminaCache.initialRedRatio = StaminaCache.redRatio
        StaminaCache.lastHitTimestamp = simTime
        StaminaCache.fadeStartTimestampe = nil
        StaminaCache.fadeStartStamina = nil
            
        -- if StaminaCache.fadeStartTimestampe == nil then
        --     StaminaCache.fadeStartStamina = nil
        -- end

        -- if StaminaCache.lastRatio > StaminaCache.peakRatio then
        --     StaminaCache.peakRatio = StaminaCache.lastRatio
        -- end
    elseif StaminaCache.initialRedRatio > 0 and 
        (simTime - StaminaCache.lastHitTimestamp > conf.UsedStaminaDelay or 
        (current <= 0 and simTime - StaminaCache.lastHitTimestamp > conf.UsedStaminaDelay)) then
        if StaminaCache.fadeStartTimestampe == nil then
            StaminaCache.fadeStartTimestampe = simTime
            StaminaCache.fadeStartStamina = ratio
            StaminaCache.initialRedRatio = StaminaCache.redRatio
        else
            local fadeTime = conf.UsedStaminaFadeTime
            local elapsed = math.min(simTime - StaminaCache.fadeStartTimestampe, fadeTime)
            local progress = math.min(elapsed / fadeTime, 1)

            -- Ease out
            StaminaCache.redRatio = StaminaCache.initialRedRatio * (1 - progress)^2
            
            -- StaminaCache.redRatio = math.max(StaminaCache.redRatio+StaminaCache.fadeStartStamina-ratio, 0)
            local theoryRed = StaminaCache.redRatio + StaminaCache.fadeStartStamina
            local effectiveRed = theoryRed - ratio
            if effectiveRed < 0 then
                effectiveRed = 0
            end
            StaminaCache.redRatio = math.max(math.min(StaminaCache.redRatio, effectiveRed), 0)
            if StaminaCache.redRatio <= 0 then
                StaminaCache.redRatio = 0
                StaminaCache.initialRedRatio = 0
                StaminaCache.fadeStartTimestampe = nil
                StaminaCache.fadeStartStamina = nil
            end
        end
    end

    -- peakRatio 模式如果不增加 lastRatio check，会导致跑步没有白条，但是可以让每次翻滚都生成新的白条
    -- if ratio + StaminaCache.redRatio > StaminaCache.peakRatio then
    --     StaminaCache.redRatio = StaminaCache.peakRatio - ratio
    -- end
    StaminaCache.lastRatio = ratio
end

mod.OnDebugFrame(function ()
    imgui.text("Hunter Stats")

    if Data.HunterData.HealthData then
        local data = Data.HunterData.HealthData
        imgui.text(string.format("HP: %s/%s, Red: %s, Heal: %s", tostring(data.Health), tostring(data.MaxHealth), tostring(data.RedHealth), tostring(data.Heal)))
    end

    if Data.HunterData.StaminaData then
        local data = Data.HunterData.StaminaData
        imgui.text(string.format("SP: %s/%s, Limit: %s", tostring(data.Stamina), tostring(data.MaxStamina), tostring(data.StaminaLimit)))
        imgui.text(string.format("SP: %s%% (Used)", tostring(StaminaCache.redRatio*100)))
        imgui.text(string.format("SP: %s/%s (Tough)", tostring(data.StaminaTough), tostring(data.MaxStaminaTough)))
    end
end)

---@return CircleConfig
local OuterStaminaRing = {
    Enable = true,
    Absolute = true,
    IsFill = true,
    IsRing = true,
    Radius = 44,
    RingWidth = 24,
    Color = Draw.ReverseRGB(0xFF65D84D), -- Draw.ReverseRGB(0xFF76B295), -- Draw.ReverseRGB(0xFF8EB116),
    BackgroundRatio = 1,
    UseBackground = true,
    BackgroundColor = Draw.ReverseRGB(0x90000000),
    RingUseCircleBackground = false,
    RingAutoCircleBackgroundRadius = true,
    IsFillOutline = true,
    OutlineThickness = 0,
    OutlineColor = Draw.ReverseRGB(0xFF76B295),
    Clockwise = false,
}

---@param conf OverlayStatusHunterStaminaConfig
function _M.DrawStamina(x, y, data, ratio, conf)
    if not conf.StaminaCircle.Enable then
        return
    end
    local perSegValue = conf.SegmentValue
    local maxSegIndex = math.ceil(data.MaxStamina/conf.SegmentValue)
    if not conf.Segmented then
        perSegValue = data.MaxStamina
        maxSegIndex = 1
    end

    local currentSegIndex = math.ceil(data.Stamina / perSegValue)
    if currentSegIndex == 0 then
        currentSegIndex = 1
    end
    local currentSegMax = perSegValue
    if currentSegIndex == maxSegIndex then
        currentSegMax = data.MaxStamina - (maxSegIndex - 1) * perSegValue
    end
    local currentSegCurrent = data.Stamina - (currentSegIndex-1)*perSegValue

    if conf.ShowUsedStamina then
        local ExpectedMax = currentSegMax
        if conf.Segmented then
            ExpectedMax = conf.SegmentValue
        end
        UpdateUsedStamina(currentSegCurrent, ExpectedMax, currentSegIndex, conf)
    end

    local wasColor = conf.StaminaCircle.Color
    local color = wasColor
    
    if ratio <= conf.ThresholdRatio or data.Stamina <= conf.ThresholdValue then
        color = conf.ThresholdColor
    elseif conf.EnableColorTransition then
        local gradientRatio = 1-(ratio-conf.ThresholdRatio)/(1-conf.ThresholdRatio)
        color = Draw.LinearGradientColor(wasColor, conf.TransitionToColor, gradientRatio)
    end

    PlayerStaminaCanvas.Debug(mod.Config.Debug)
    PlayerStaminaCanvas.Init()
    local CenterR = conf.StaminaCircle.Radius
    for i = 1, maxSegIndex, 1 do
        local current, max
        local ratio
        if i == currentSegIndex then
            current = currentSegCurrent
            max = currentSegMax
            ratio = current/max
        elseif i > currentSegIndex then
            current = 0
            ratio = 0
            if currentSegIndex == 1 then
                max = data.MaxStamina - (maxSegIndex - 1) * perSegValue
            else
                max = perSegValue
            end
        else
            current = perSegValue
            max = perSegValue
            ratio = 1
        end

        local MaxRatio = 1
        if i == maxSegIndex or i == 1 then
            local ExpectedMax = 100
            if conf.Segmented then
                ExpectedMax = conf.SegmentValue
            end
            -- i == maxSegIndex: 体力小于100，太饿了的时候
            -- i == 1: 体力不足以填满新的槽
            MaxRatio = math.min(1, max / ExpectedMax)
            if MaxRatio < 1 then
                ratio = current / ExpectedMax
            end
        end

        if i == 1 then
            -- 绘制最内圈
            conf.StaminaCircle.BackgroundRatio = MaxRatio
            conf.StaminaCircle.Color = color

            PlayerStaminaCanvas.RePos(x, y)

            if not conf.ShowUsedStamina or ratio == 0 or ratio == 1 then
                PlayerStaminaCanvas.Circle(conf.StaminaCircle, ratio)
            else
                PlayerStaminaCanvas.Circle(conf.StaminaCircle, ratio, StaminaCache.redRatio, conf.UsedStaminaColor)
            end

            conf.StaminaCircle.Color = wasColor
            conf.StaminaCircle.BackgroundRatio = 1
        else
            -- 绘制任何外圈
            OuterStaminaRing.Enable = conf.StaminaCircle.Enable
            OuterStaminaRing.BackgroundRatio = MaxRatio
            OuterStaminaRing.Color = color

            OuterStaminaRing.RingWidth = conf.SegmentRingWidth
            OuterStaminaRing.Radius = conf.StaminaCircle.Radius + (conf.SegmentRingWidth + conf.SegmentRingMargin)*(i-1)
            local dr = OuterStaminaRing.Radius - CenterR

            PlayerStaminaCanvas.RePos(x-dr, y-dr)

            if not conf.ShowUsedStamina or ratio == 0 or ratio == 1 then
                PlayerStaminaCanvas.Circle(OuterStaminaRing, ratio)
            else
                PlayerStaminaCanvas.Circle(OuterStaminaRing, ratio, StaminaCache.redRatio, conf.UsedStaminaColor)
            end
            OuterStaminaRing.BackgroundRatio = 1
        end
    end
    PlayerStaminaCanvas.End()
end

---@param conf OverlayStatusHunterStaminaConfig
function _M.DrawInsectStamina(x, y, data, ratio, conf)
    local wasColor = conf.InsectStaminaCircle.Color
    local color = wasColor
    
    if ratio <= conf.InsectThresholdRatio or data.Stamina <= conf.InsectThresholdValue then
        color = conf.InsectThresholdColor
    elseif conf.InsectEnableColorTransition then
        local gradientRatio = 1-(ratio-conf.InsectThresholdRatio)/(1-conf.InsectThresholdRatio)
        color = Draw.LinearGradientColor(wasColor, conf.InsectTransitionToColor, gradientRatio)
    end

    PlayerStaminaCanvas.Debug(mod.Config.Debug)
    PlayerStaminaCanvas.Init()
    local CenterR = conf.InsectStaminaCircle.Radius

    -- 绘制最内圈
    conf.InsectStaminaCircle.BackgroundRatio = ratio
    conf.InsectStaminaCircle.Color = color

    PlayerStaminaCanvas.RePos(x, y)
    PlayerStaminaCanvas.Circle(conf.InsectStaminaCircle, ratio)

    conf.InsectStaminaCircle.Color = wasColor
    conf.InsectStaminaCircle.BackgroundRatio = 1

    PlayerStaminaCanvas.End()
end


-- mod.OnFrame(function ()
--     if Data.HunterData.WeaponType == CONST.WeaponType.InsectGlaive then
--         local data = Data.HunterData.InsectStaminaData
--         imgui.text(string.format("%s/%s - %s", tostring(data.Stamina), tostring(data.MaxStamina), tostring(data.Ratio)))
--     end
-- end)


local Smoother = require("_CatLib.smoother").new(0.1)
function _M.DrawPlayer()
    local pos = Data.HunterData.Pos
    local data = Data.HunterData.StaminaData
    if pos and data and data.Stamina and Config.HunterConfig.Stamina.Enable then
        local conf = Config.HunterConfig.Stamina
        local ratio = 0
        ratio = data.Stamina/data.MaxStamina -- 200

        local autoHideTimeout = conf.AutoHide and OverlayData.SimulatedTime - StaminaCache.LastNonFillTime > conf.DisappearDelay
        local isIG = Data.HunterData.WeaponType == CONST.WeaponType.InsectGlaive
        if autoHideTimeout and ratio >= 1 and not isIG then
            -- disappear
        else
            if ratio < 1 then
                StaminaCache.LastNonFillTime = OverlayData.SimulatedTime
            end

            local x, y
            if conf.RelativePosition then
                local uix = pos.x + conf.WorldOffsetX
                local uiy = pos.y + conf.WorldOffsetY
                local uiz = pos.z + conf.WorldOffsetZ
                local uiPos = Vector3f.new(uix, uiy, uiz)
                local screenPos = draw.world_to_screen(uiPos)
                if screenPos then
                    x = screenPos.x + conf.RelativeOffsetX
                    y = screenPos.y + conf.RelativeOffsetY
                    x, y = Smoother:update(x, y)
                end
            else
                x, y = conf.FixedOffsetX, conf.FixedOffsetY
            end
            if x and y then
                if autoHideTimeout and ratio >= 1 then
                    -- disappear
                else
                    _M.DrawStamina(x, y, data, ratio, conf)
                end

                if isIG then
                    local data = Data.HunterData.InsectStaminaData
                    local ratio = data.Ratio
                    local offset = 0
                    if conf.InsectStaminaCircleCenterPlayer then
                        offset = conf.StaminaCircle.Radius - conf.InsectStaminaCircle.Radius
                    end
                    if autoHideTimeout and ratio >= 1 then
                        -- disappear
                    else
                        _M.DrawInsectStamina(x+offset, y+offset, data, ratio, conf)
                    end
                end
            end
        end
    end
end

function _M.DrawAll()
    if Core.IsLoading() then return end

    _M.DrawPlayer()
    _M.DrawBuffs()
end

local SkillToGroupSkillFunc = Core.TypeMethod("app.HunterSkillDef", "convertSkillToGroupSkill(app.HunterDef.Skill)")

---@param data BuffStatus
local function DebugShowBuff(key,data)
    local enabled = "Enabled"
    if not data.Activated then
        enabled = "Disabled"
    end
    if data.Level then
        imgui.text(string.format("[%s] %s Lv%d(%s): %0.1f/%0.1f", enabled, tostring(data.Name), data.Level, tostring(key), data.Timer, data.MaxTimer))
    else
        imgui.text(string.format("[%s] %s(%s): %0.1f/%0.1f", enabled, tostring(data.Name), tostring(key), data.Timer, data.MaxTimer))
    end
end

mod.OnDebugFrame(function ()
    -- if true then
    --     return
    -- end
    imgui.push_font(Core.LoadImguiCJKFont())
    -- for i = 1, 209, 1 do
    --     local groupSkill = SkillToGroupSkillFunc:call(nil, i)
    --     local name = Core.GetSkillName(i)

    --     imgui.text(string.format("%d: %s -> %d: %s", i, name, groupSkill, Core.GetSkillName(groupSkill)))
    --     imgui.text(string.format("%d: %s, %s, %s", i, Core.GetSkillName(i, 1), Core.GetSkillName(i, 2), Core.GetSkillName(i, 3)))
    -- end

    for key, data in pairs(Data.SkillData) do
        if not data.Name then
            Data.SkillData[key].Name = Core.GetSkillName(key, data.Level)
        end
        DebugShowBuff(key,data)
    end
    for key, data in pairs(Data.MuiscSkillData) do
        if not data.Name then
            Data.MuiscSkillData[key].Name = Core.GetMusicSkillName(key)
        end
        DebugShowBuff(key,data)
    end
    for key, data in pairs(Data.OtomoSkillData) do
        DebugShowBuff(key,data)
    end
    for key, data in pairs(Data.ItemBuffData) do
        if not data.Name then
            Data.ItemBuffData[key].Name = key
        end
        DebugShowBuff(key,data)
    end
    for key, data in pairs(Data.ASkillData) do
        if not data.Name then
            Data.ASkillData[key].Name = Core.GetASkillName(key)
        end
        DebugShowBuff(key,data)
    end

    for key, data in pairs(Data.WeaponBuffData) do
        DebugShowBuff(key,data)
    end
end)

mod.D2dRegister(function ()
end, function ()
    if not Config.Enable then return end

    mod.RecordCost("PlayerStauts", function ()
        _M.DrawAll()
    end)
end, "PlayerStatus")

return _M
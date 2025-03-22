local re = re
local sdk = sdk
local d2d = d2d
local imgui = imgui
local log = log
local json = json
local draw = draw
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
local CONST = require("_CatLib.const")

local mod = require("mhwilds_overlay.mod")
local OverlayData = require("mhwilds_overlay.data")

local _M = {}

local ElementImages = {}
local CrownImages = {}

local EnemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")
local EnemyImages = {}
local EnemyImageUnknown

---@param ctx EnemyContext
local function TryLoadEnemyImage(ctx)
    local emId = ctx:get_EmID()
    local name = EnemyIdNameMap[emId]
    if not name then return end

    if EnemyImages[name] == false then
        return EnemyImageUnknown
    end
    if EnemyImages[name] ~= nil then
        return EnemyImages[name]
    end

    local iconPath = string.format("enemy/small/tex000201_1_IMLM4.tex.241106027_%s.png", string.upper(name))

    local image = mod.LoadImage(iconPath)
    if image then
        EnemyImages[name] = image
        return image
    end
    EnemyImages[name] = false
    -- log.error(string.format("Enemy Icon: %s missing", iconPath))
    return EnemyImageUnknown
end

-- Red HP part
---@class RedHpCtxCache
---@field lastRatio number
---@field lastHitTimestamp number
---@field redRatio number
---@field initialRedRatio number
---@field fadeStartTimestampe number

---@class RedHpCache
---@field simulatedTime number
---@field lastTime number
---@field lastIsSegmented number
---@field lastSegmentedMode number
---@field lastSegmentedValue number
---@field lastSegmentedPercentage number
---@field lastSegmentedInBar boolean
---@field Cache table<EnemyContext, RedHpCtxCache>

---@return RedHpCtxCache
local function NewCtxRedHpCache()
    return {
        lastRatio = 1,
        lastHitTimestamp = -1,
        redRatio = 0,
        initialRedRatio = 0,  -- 消逝过程中，初始的 red ratio
        fadeStartTimestampe = nil, -- 消逝起始时间
    }
end

---@return RedHpCache
local function NewRedHpCache()
    return {
        simulatedTime = 0, -- 任务停止后 QuestTime 停了，模拟时间
        lastTime = 0, -- 检测任务时间是否停止
        lastIsSegmented = false, -- 切换 seg mode 时清空
        lastSegmentedMode = false, -- 切换 seg mode 时清空
        lastSegmentedValue = 0, -- 切换 seg value 时清空
        lastSegmentedPercentage = 0, -- 切换 seg value 时清空
        lastSegmentedInBar = false,

        Cache = {},
    }
end
---@type table<HpWidgetTheme, RedHpCache>
_M.RedHpCache = {}
_M.QuestElapsedTime = -1
_M.QuestTimeLimit = 1

mod.OnDebugFrame(function ()
    if _M.QuestElapsedTime <= 0 then
        return
    end

    for _, cache in pairs(_M.RedHpCache) do
        imgui.text(string.format("QuestTime %0.1f, SimTime: %0.1f", _M.QuestElapsedTime, cache.simulatedTime))
        for _, data in pairs(cache.Cache) do
            imgui.text(string.format("Last: ratio: %0.1f%%, hit timestamp: %0.1f", data.lastRatio*100, data.lastHitTimestamp))
            imgui.text(string.format("Now timestamp: %0.1f, delta: %0.1f", _M.QuestElapsedTime, _M.QuestElapsedTime - data.lastHitTimestamp))
            if data.redRatio then
                imgui.text(string.format("Red Ratio: %0.1f%%, fadeTime: %0.1f", data.redRatio*100, data.fadeStartTimestampe or -1))
            end
        end
        imgui.text("")
    end
end)


function _M.ClearData()
    _M.RedHpCache = {}
    _M.QuestElapsedTime = -1
    _M.QuestTimeLimit = 1
end

local EnemySmallIconRect = {
    Enable = true,
    Width = 32,
    Height = 32,
    VerticalCenter = true,
    MarginX = 0,
}

local EnemyCrownRect = {
    Enable = true,
    Width = 32,
    Height = 32,
    VerticalCenter = true,
    MarginX = 0,
}

local ElementIconRect = {
    Enable = true,
    Width = 32,
    Height = 32,
    VerticalCenter = true,
    MarginX = 0,
}

local HpHeaderCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})
local HpBarsCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})
local HpSegementIndicatorsCanvas = Draw.NewDivCanvas({
    Enable = true,
    Width = 32,
    Height = 32,
    UseBackground = false,
})


local EnemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")

---@param conf HpWidgetHeader
local function DrawHeaderText(conf, ctx, canvas, id, hpCurrent, hpMax, showQuest, captureRatio, capturable)
    if not conf.Enable then return end
    
    canvas.Debug(mod.Config.Debug)
    canvas.Init()

    local maxH = 0
    if conf.AutoCrownSize or conf.AutoWeaknessIconSize or conf.ShowSmallIcon then
        if conf.Name.Enable then
            local _, h = Draw.Measure(conf.Name, "4000")
            maxH = math.max(maxH, h)
        end
        if conf.HP.Enable then
            local _, h = Draw.Measure(conf.HP, "4000")
            maxH = math.max(maxH, h)
        end
        if conf.Action and conf.Action.Enable then
            local _, h = Draw.Measure(conf.Action, "4000")
            maxH = math.max(maxH, h)
        end
        if conf.QuestTime and conf.QuestTime.Enable then
            local _, h = Draw.Measure(conf.QuestTime, "4000")
            maxH = math.max(maxH, h)
        end
    end

    if conf.ShowSmallIcon then
        local img = TryLoadEnemyImage(ctx)
        if img then
            EnemyCrownRect.Width = maxH
            EnemyCrownRect.Height = maxH
            canvas.Image(EnemySmallIconRect, img)   
        end
    end

    if conf.Name.Enable then
        local msg = Core.GetEnemyName(id)
        if mod.Config.Debug then
            local emId = ctx:get_EmID()
            local name = EnemyIdNameMap[emId]
            msg = name .. " " .. msg
        end
        canvas.Text(conf.Name, msg)
    end

    if conf.ShowCrownIcon then
        local crown = OverlayData.EnemyCrown[ctx]
        if crown and crown > CONST.CrownType.None then
            local img = CrownImages[crown]
            if img then
                local h = maxH
                if h == 0 or not conf.AutoCrownSize then
                    h = conf.CrownIconSize
                end
                EnemyCrownRect.Width = h
                EnemyCrownRect.Height = h
                canvas.Image(EnemyCrownRect, img)
            else
                canvas.Text(conf.HP, CONST.CrownTypeNames[crown])
            end
        end
        if mod.Config.Debug then
            canvas.Text(conf.HP, tostring(OverlayData.EnemyScale[ctx]))
        end
    end

    if conf.HP.Enable then
        if conf.ShowHPRatio then
            canvas.Text(conf.HP, string.format("%0.1f%%", hpCurrent/hpMax*100))
        elseif conf.ShowCurrentHpValues or conf.ShowMaxHpValues then
            local s = {}
            if conf.ShowCurrentHpValues then
                s[#s+1] = tostring(hpCurrent)
            end
            if conf.ShowMaxHpValues then
                if conf.ShowCurrentHpValues then
                    s[#s+1] = "/"
                end
                s[#s+1] = tostring(hpMax)
            end

            canvas.Text(conf.HP, table.concat(s,""))
        end
    end

    if mod.Config.Debug and captureRatio ~= nil then
        canvas.Text(conf.HP, string.format(" Threshold: %0.1f%%", captureRatio*100))
    end
    if mod.Config.Debug and capturable ~= nil then
        if capturable == true then
            canvas.Text(conf.HP, " Capturable")
        else
            canvas.Text(conf.HP, " No Capturable")
        end
    end

    local idKey = tostring(id)
    if conf.ShowWeaknessIcon and OverlayData.EnemyElementMeat[idKey] then
        for i, data in pairs(OverlayData.EnemyElementMeat[idKey]) do
            if not mod.Config.Debug then
                if data.Meat < 19.9 then
                    break
                end                
            end

            local img = ElementImages[data.Type]
            if img then
                local h = maxH
                if h == 0 or not conf.AutoWeaknessIconSize then
                    h = conf.WeaknessIconSize
                end
                ElementIconRect.Width = h
                ElementIconRect.Height = h
                canvas.Image(ElementIconRect, img)
                if conf.ShowWeaknessDetail then
                    canvas.Text(conf.HP, string.format("%d", math.ceil(data.Meat)))
                end
            else
                -- canvas.Text(conf.HP, string.format("%s: %d", data.Type, math.ceil(data.Meat)))
            end
            if mod.Config.Debug then
                canvas.Text(conf.HP, tostring(data.Meat))
            end
        end
    end

    if conf.Action and conf.Action.Enable then
        local actionController = OverlayData.EnemyInfo[ctx].ActionController
        if actionController then
            local current = actionController._CurrentActionID

            local curCate = current._Category
            local curIdx = current._Index

            local enemy = OverlayData.EnemyInfo[ctx].Character

            ---@type app.CharacterParamHolder
            local charaParamHolder = enemy:get_CharaParamHolder()
            -- TODO: FIXME：有时候任务结束了但是居然没清空？？为什么
            if charaParamHolder then
                local actionDict = charaParamHolder:get_ActionDictionary()._ActionIDHolder
                if actionDict:getActionCategory() == curCate then
                    local ids = actionDict._ActionID._ActionIDArray:get_DataArray()
                    local data = ids:get_Item(curIdx)

                    ---@type string
                    local name = data._Class
                    if name:sub(1, 1) == "c" then
                        name = name:sub(2)
                    end
                    canvas.Text(conf.Action, name)
                end
            end

            if mod.Config.Debug then
                local next = actionController._NextActionID
                local nextCate = next._Category
                local nextIdx = next._Index
                canvas.Text(conf.Action, string.format(" %d/%d -> %d/%d", curCate, curIdx, nextCate, nextIdx))
            end
        end
    end

    if showQuest and conf.QuestTime and conf.QuestTime.Enable then
        local elapsed = _M.QuestElapsedTime
        local elapsedMin = math.floor(elapsed / 60.0)
        local elapsedSecs = elapsed % 60.0
        local limit = math.floor(_M.QuestTimeLimit)

        local msg = string.format("%02d:%02.0f/%d:00", elapsedMin, elapsedSecs, limit)

        canvas.Text(conf.QuestTime, msg)
    end

    canvas.End()
end

---@param conf HpWidgetHpSegement
---@param canvas DivCanvas
local function DrawHpSegment(conf, canvas, hpCurrent, hpMax, hpRatio, segmentHpCurrent, segmentHpMax, totalLives, remainLives)
    if not conf.Enable or not conf.Indicator.Enable or hpCurrent <= 0 then
        return canvas.NextPos()
    end

    local needDisplay = (not conf.Indicator.HideDrainIndicator) or (remainLives > 0)

    local display = needDisplay or mod.Config.Debug
    if not display then
        return canvas.NextPos()
    end

    canvas.Debug(mod.Config.Debug)
    canvas.Init()

    if mod.Config.Debug then
        canvas.Text({
            BlockRenderX = true,
            BlockRenderY = true,
        }, string.format("RemainLives: %d/%d - %d/%d", remainLives, totalLives, segmentHpCurrent, segmentHpMax))
    end

    local indiConf = conf.Indicator
    for i = 0, totalLives-1, 1 do
        if i >= remainLives and conf.Indicator.HideDrainIndicator then
            goto continue
        end
        local x, y = canvas.NextPos()

        local ratio = 1
        if i == remainLives-1 then
            ratio = hpRatio
        elseif i >= remainLives then
            ratio = 0
        end

        if indiConf.UseCircleShape then
            canvas.Circle(indiConf.Circle, ratio)
        else                
            canvas.Rect(indiConf.Rect, ratio)
        end

        if mod.Config.Debug then
            Draw.Text(x, y, 0xFFFFFFFF, tostring(i))
        end

        ::continue::
    end

    local endX, endY = canvas.NextPos()
    canvas.End()
    if indiConf.UseCircleShape then
        endY = endY + indiConf.Circle.Radius*2
    else                
        endY = endY + indiConf.Rect.Height
    end

    return endX, endY
end

---@param theme HpWidgetTheme
---@param ctx EnemyContext
function _M.DrawHpBar(theme, ctx, x, y, width, height, showQuest, captureRatio, capturable)
    if not theme.Enable then return x, y end

    local data = OverlayData.EnemyInfo[ctx]

    local startX = x
    local startY = y
    -- Health

    local hpCurrent = math.ceil(data.HP)
    local hpMax = math.ceil(data.MaxHP)
    local hpRatio = hpCurrent/hpMax

    local segmentHpCurrent = hpCurrent
    local segmentHpMax = hpMax
    local segmentRatio = segmentHpCurrent/segmentHpMax
    local remainLives = 1
    local totalLives = 1

    -- HP Segement
    if theme.Hp.Enable and theme.HpSegement and theme.HpSegement.Enable then
        local SEGMENT_MAX = theme.HpSegement.SegmentValue -- 血条长度
        if theme.HpSegement.UsePercentageSegment then
            SEGMENT_MAX = math.ceil(theme.HpSegement.SegmentPercentage / 100 * hpMax)
        end
        local lives = math.ceil(hpMax / SEGMENT_MAX) -- 总血条数量 5000 -> 2000+2000+1000
        if lives <= 0 then
            lives = 1
        end
        totalLives = lives

        local firstLifeHp = hpMax % SEGMENT_MAX

        local normalizedHpMax = hpMax
        if firstLifeHp > 1 and hpMax - hpCurrent > firstLifeHp then
            normalizedHpMax = hpMax + (SEGMENT_MAX -  firstLifeHp)
        end

        local usedLives = math.floor((normalizedHpMax - hpCurrent) / SEGMENT_MAX) -- 已消耗的血条数量
        remainLives = lives - usedLives -- 4000 -> 2, 4500 -> 2
        if remainLives == 0 then
            remainLives = 1
        end

        local currentLifeMaxHp = SEGMENT_MAX
        local currentLifeHp = hpCurrent - ((remainLives-1)*SEGMENT_MAX)

        currentLifeMaxHp = math.min(currentLifeMaxHp, hpMax)

        if currentLifeHp <= 0 then
            remainLives = 0
        end
        segmentHpCurrent = currentLifeHp
        segmentHpMax = currentLifeMaxHp
        segmentRatio = currentLifeHp/currentLifeMaxHp
        if theme.HpSegement.UseSegHpValueInBar then
            hpRatio = segmentRatio
        end
    end
    segmentHpCurrent = math.ceil(segmentHpCurrent)
    segmentHpMax = math.ceil(segmentHpMax)

    local nextX, nextY = startX, startY

    -- Text
    local TextX, TextY = nextX, nextY
    local topBarWidth = 0
    if theme.Hp.Enable and topBarWidth == 0 then
        topBarWidth = theme.Hp.Width + theme.Hp.OffsetX
    elseif theme.Stamina and theme.Stamina.Enable and topBarWidth == 0 then
        topBarWidth = theme.Stamina.Width + theme.Stamina.OffsetX
    elseif theme.Angry and theme.Angry.Enable and topBarWidth == 0 then
        topBarWidth = theme.Angry.Width + theme.Angry.OffsetX
    else
        topBarWidth = width
    end

    if theme.Header.Enable then
        local posX = TextX + theme.Header.OffsetX
        local posY = TextY + theme.Header.OffsetY
        HpHeaderCanvas.RePos(posX, posY)

        local h = theme.Header.Height
        if h <= 0 then
            h = 1
        end
        HpHeaderCanvas.ReSize(topBarWidth-5, h)
        HpHeaderCanvas.PaddingX = theme.Header.PaddingX

        local id = ctx:get_EmID()
        if theme.HpSegement and theme.HpSegement.UseSegHpValueInText then
            DrawHeaderText(theme.Header, ctx, HpHeaderCanvas, id, segmentHpCurrent, segmentHpMax, showQuest, captureRatio, capturable)
        else
            DrawHeaderText(theme.Header, ctx, HpHeaderCanvas, id, hpCurrent, hpMax, showQuest, captureRatio, capturable)
        end
        HpHeaderCanvas.End()

        nextX, nextY = startX, posY + h
    end
    -- TODO: Text
    -- Draw.Text(HealthXUpL, HealthYUpL, 0xFFFFFFFF, string.format("%0.1f/%0.0f (%0.1f%%)", hpCurrent, hpMax, hpRatio*100))
    -- Draw.Text(StaminaXUpL, StaminaYUpL, 0xFFFFFFFF, string.format("%0.1f/%0.0f (%0.1f%%)", spCurrent, spMax, spRatio*100))

    if theme.Hp.Enable and theme.RedHp and theme.RedHp.Enable then
        local QuestElapsedTime = _M.QuestElapsedTime

        if _M.RedHpCache[theme] == nil then
            _M.RedHpCache[theme] = NewRedHpCache()
        end

        if theme.HpSegement then
            if _M.RedHpCache[theme].lastIsSegmented ~= theme.HpSegement.Enable or 
            _M.RedHpCache[theme].lastSegmentedMode ~= theme.HpSegement.UsePercentageSegment or 
            _M.RedHpCache[theme].lastSegmentedValue ~= theme.HpSegement.SegmentValue or 
            _M.RedHpCache[theme].lastSegmentedPercentage ~= theme.HpSegement.SegmentPercentage or 
            _M.RedHpCache[theme].lastSegmentedInBar ~= theme.HpSegement.UseSegHpValueInBar then
                _M.RedHpCache[theme].Cache = {}
                _M.RedHpCache[theme].Cache[ctx] = NewCtxRedHpCache()
                _M.RedHpCache[theme].Cache[ctx].lastRatio = hpRatio
            end
            _M.RedHpCache[theme].lastIsSegmented = theme.HpSegement.Enable
            _M.RedHpCache[theme].lastSegmentedMode = theme.HpSegement.UsePercentageSegment
            _M.RedHpCache[theme].lastSegmentedValue = theme.HpSegement.SegmentValue
            _M.RedHpCache[theme].lastSegmentedPercentage = theme.HpSegement.SegmentPercentage
            _M.RedHpCache[theme].lastSegmentedInBar = theme.HpSegement.UseSegHpValueInBar
        end

        local simTime = OverlayData.SimulatedTime

        if _M.RedHpCache[theme].Cache[ctx] == nil then
            _M.RedHpCache[theme].Cache[ctx] = NewCtxRedHpCache()
        end

        if _M.RedHpCache[theme].Cache[ctx].lastHitTimestamp <= 0 then
            _M.RedHpCache[theme].Cache[ctx].lastRatio = hpRatio
            _M.RedHpCache[theme].Cache[ctx].lastHitTimestamp = simTime
        end

        local RedCtxCache = _M.RedHpCache[theme].Cache[ctx]

        -- 百分比变多了
        if hpRatio > RedCtxCache.lastRatio then
            RedCtxCache.redRatio = 1 - hpRatio
            RedCtxCache.initialRedRatio = RedCtxCache.redRatio
        end

        _M.RedHpCache[theme].lastTime = simTime

        if hpRatio < RedCtxCache.lastRatio then
            if RedCtxCache.fadeStartTimestampe == nil then
                RedCtxCache.redRatio = RedCtxCache.lastRatio - hpRatio + RedCtxCache.redRatio
            else
                -- 衰减中，则直接清空
                RedCtxCache.redRatio = RedCtxCache.lastRatio - hpRatio
            end
            RedCtxCache.initialRedRatio = RedCtxCache.redRatio
            RedCtxCache.lastHitTimestamp = simTime
            RedCtxCache.fadeStartTimestampe = nil
        elseif simTime - RedCtxCache.lastHitTimestamp > theme.RedHp.DelayTime or 
            (hpCurrent <= 0 and simTime - RedCtxCache.lastHitTimestamp > theme.RedHp.DelayTime) then
            if RedCtxCache.fadeStartTimestampe == nil then
                RedCtxCache.fadeStartTimestampe = simTime
                RedCtxCache.initialRedRatio = RedCtxCache.redRatio
            else
                local fadeTime = theme.RedHp.FadeTime
                local elapsed = math.min(simTime - RedCtxCache.fadeStartTimestampe, fadeTime)
                local progress = math.min(elapsed / fadeTime, 1)

                -- Ease out
                RedCtxCache.redRatio = RedCtxCache.initialRedRatio * (1 - progress)^2
            end
        end

        RedCtxCache.lastRatio = hpRatio

        _M.RedHpCache[theme].Cache[ctx] = RedCtxCache
    end

    HpBarsCanvas.RePos(nextX, nextY)
    HpBarsCanvas.ReSize(width, height)
    HpBarsCanvas.Debug(mod.Config.Debug)
    HpBarsCanvas.Init()

    if theme.Hp.Enable then
        if theme.CaptureStatus and theme.CaptureStatus.Enable then
            if theme.RedHp and theme.RedHp.Enable then
                HpBarsCanvas.Rect(theme.Hp, hpRatio, _M.RedHpCache[theme].Cache[ctx].redRatio, theme.RedHp.Color, captureRatio)
            else
                HpBarsCanvas.Rect(theme.Hp, hpRatio, nil, nil, captureRatio)
            end
        else
            if theme.RedHp and theme.RedHp.Enable then
                HpBarsCanvas.Rect(theme.Hp, hpRatio, _M.RedHpCache[theme].Cache[ctx].redRatio, theme.RedHp.Color)
            else
                HpBarsCanvas.Rect(theme.Hp, hpRatio)
            end
        end
    end

    -- Stamina & Angry
    if (theme.Stamina and theme.Stamina.Enable) or (theme.Angry and theme.Angry.Enable) then
        local conds = ctx.Conditions._Conditions

        -- Stamina
        if theme.Stamina and theme.Stamina.Enable then
            local spCurrent
            local spMax
            local tired = conds:get_Item(1)
            if tired:get_IsActive() then
                spMax = tired:get_ActivateTime()
                spCurrent = spMax - tired:get_CurrentTimer()
            else
                spCurrent = tired:get_Stamina()
                spMax = tired:get_DefaultStamina()
            end
            local spRatio = spCurrent/spMax
            HpBarsCanvas.Rect(theme.Stamina, spRatio)
        end

        -- Angry
        if theme.Angry and theme.Angry.Enable then
            local angry = conds:get_Item(0)
            local agCurrent
            local agMax
            if angry:get_IsActive() then
                agMax = angry:get_ActivateTime()
                agCurrent = agMax - angry:get_CurrentTimer()
            else
                agCurrent = angry:get_Value()
                agMax = angry:get_LimitValue()
            end
            local agRatio = agCurrent/agMax
            HpBarsCanvas.Rect(theme.Angry, agRatio)
        end
    end

    _, nextY = HpBarsCanvas.NextPos()
    -- Segment HP Indicators
    if theme.HpSegement and theme.HpSegement.Enable then
        local posY = nextY + theme.HpSegement.Indicator.OffsetY

        HpSegementIndicatorsCanvas.RePos(startX + theme.HpSegement.Indicator.OffsetX, posY)
        HpSegementIndicatorsCanvas.ReSize(topBarWidth, 48)
        local _, segEndY = DrawHpSegment(theme.HpSegement, HpSegementIndicatorsCanvas, hpCurrent, hpMax, segmentRatio, segmentHpCurrent, segmentHpMax, totalLives, remainLives)

        nextY = math.max(nextY, segEndY)
    end

    HpBarsCanvas.End()

    return x, nextY
end

mod.D2dRegister(function ()
    ElementImages["Fire"] = mod.LoadImage("icons/fire.png")
    ElementImages["Water"] = mod.LoadImage("icons/water.png")
    ElementImages["Ice"] = mod.LoadImage("icons/ice.png")
    ElementImages["Thunder"] = mod.LoadImage("icons/thunder.png")
    ElementImages["Dragon"] = mod.LoadImage("icons/dragon.png")

    CrownImages[CONST.CrownType.Small] = mod.LoadImage("icons/crown_small.png")
    CrownImages[CONST.CrownType.Big] = mod.LoadImage("icons/crown_silver.png")
    CrownImages[CONST.CrownType.King] = mod.LoadImage("icons/crown_king.png")
    
    EnemyImageUnknown = mod.LoadImage("enemy/small/tex000201_1_IMLM4.tex.241106027_EM0000_00_0.png")
end, function ()
end)

return _M
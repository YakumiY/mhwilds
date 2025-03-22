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
local Div = require("_CatLib.div")
local CONST = require("_CatLib.const")


local mod = require("mhwilds_overlay.mod")
local OverlayDrawHp = require("mhwilds_overlay.draw.hp")

local OverlayData = require("mhwilds_overlay.data")
local Config = require("mhwilds_overlay.boss.conf")
local Data = require("mhwilds_overlay.boss.data")

local _M = {}

local EnemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")
local ElementImages = {}
local CrownImages = {}
local EnemyImages = {}
local EnemyImageUnknown
local PlateImage
local BreakableIcon
local SeverableIcon

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

    local iconPath = string.format("enemy/tex_EmIcon_%s_IMLM4.tex.241106027.png", string.upper(name))

    local image = mod.LoadImage(iconPath)
    if image then
        EnemyImages[name] = image
        return image
    end
    EnemyImages[name] = false
    -- log.error(string.format("Enemy Icon: %s missing", iconPath))
    return EnemyImageUnknown
end

local MeatSlotNames = Core.GetEnumMap("app.user_data.EmParamParts.MEAT_SLOT")
local StateNames = Core.GetEnumMap("app.cEmModuleScar.cScarParts.STATE")

local condRowTextHeight = nil
local partRowTextHeight = nil
local scarRowTextHeight = nil
local LevelTextWidth, LevelTextHeight = nil, nil
local QuestElapsedTime = -1
local QuestTimeLimit = 1
local IsInBattle = false

---@class TimestampCache
---@field LastVal number
---@field LastChangedTimestamp number

---@type table<EnemyContext, table<app.EnemyDef.CONDITION, TimestampCache>>
_M.ConditionUpdateTimestampCache = {}
---@type table<EnemyContext, table<app.EnemyDef.PARTS_TYPE, TimestampCache>>
_M.PartUpdateTimestampCache = {}
---@type table<EnemyContext, table<integer, TimestampCache>>
_M.ScarUpdateTimestampCache = {}

local EmPartIndexCache = {}

function _M.ClearData()
    _M.ConditionUpdateTimestampCache = {}
    _M.PartUpdateTimestampCache = {}
    _M.ScarUpdateTimestampCache = {}
    QuestElapsedTime = -1
    QuestTimeLimit = 1
    IsInBattle = false

    EmPartIndexCache = {}
end

local CondCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})

---@type table<app.EnemyDef.CONDITION, CondData>
local LastCondData = {}
local LastErrs = {}
local CondEnumNames = Core.GetEnumMap("app.EnemyDef.CONDITION")
mod.OnDebugFrame(function ()
    imgui.text("DEBUG!")
    for condType, condData in pairs(LastCondData) do
        -- if condData.current > 0 then
            imgui.text(string.format("%s: Activate? %s, %0.1f/%0.1f, %0.1f%%", CondEnumNames[condType], tostring(condData.isActivate), condData.current, condData.max, condData.ratio*100))
        -- end
    end
    imgui.text("ERR REASON!")
    for _, reason in pairs(LastErrs) do
        imgui.text(reason)
    end
end)

-- 怒 cEnemyAngryCondition 打满之后，打眠再起来清空了，但是仍然是怒态
-- cond: app.cEnemyActivateValueBase, app.cEnemyBadConditionStun
---@param cond app.cEnemyBadCondition
---@param condData CondData
function _M.DrawEnemyCondition(ctx, cond, x, y, width, condData, config, condConfig)
    if not cond then return end

    local condType = condData.condType
    local isActivate = condData.isActivate
    local current = condData.current
    local max = condData.max
    local ratio = condData.ratio

    LastCondData[condType] = condData

    -- check display or not
    local alwaysShow = config.AlwaysShow or condConfig.AlwaysShow
    if not alwaysShow then
        if current <= 0 and not isActivate then
            return false
        end
    end

    -- check auto hide
    if _M.ConditionUpdateTimestampCache[ctx] == nil then
        _M.ConditionUpdateTimestampCache[ctx] = {}
    end

    local currentTime = QuestElapsedTime
    local interval = config.AutoHideSeconds
    if _M.ConditionUpdateTimestampCache[ctx][condType] == nil then
        _M.ConditionUpdateTimestampCache[ctx][condType] = {
            LastChangedTimestamp = -1,
            LastVal = -1,
        }
    end

    local hideTimer = nil
    if config.AutoHide and not alwaysShow then
        if _M.ConditionUpdateTimestampCache[ctx][condType].LastVal ~= current then
            _M.ConditionUpdateTimestampCache[ctx][condType].LastVal = current
            _M.ConditionUpdateTimestampCache[ctx][condType].LastChangedTimestamp = currentTime
        else
            hideTimer = currentTime - _M.ConditionUpdateTimestampCache[ctx][condType].LastChangedTimestamp
            if hideTimer > interval then
                -- skip unchanged
                return false
            end
        end
    end

    -- display
    local ms = {}
    local s = {}

    local count = condData.count
    if config.ShowCondLevel and count then
        s[#s+1] = string.format("[%d]", count)
    end
    if config.ShowCondName then
        if mod.Config.Debug then
            s[#s+1] = tostring(condType) .. "|" .. condConfig.DisplayName
        else
            s[#s+1] = condConfig.DisplayName
        end
    end
    if #s > 0 then
        ms[#ms+1] = table.concat(s, " ")
        s = {}
    end

    if config.ShowCondValue then
        s[#s+1] = string.format("%0.1f", current)
    end
    if config.ShowCondMaxValue then
        if config.ShowCondValue then
            s[#s+1] = "/"
        end
        s[#s+1] = string.format("%d", max)
    end
    if mod.Config.Debug then
        s[#s+1] = " - " .. Core.FloatFixed1(hideTimer)
        s[#s+1] = " - " .. Core.FloatFixed1(ratio * 100) .. "%"
    end
    if #s > 0 then
        ms[#ms+1] = table.concat(s, "")
    end
    
    CondCanvas.RePos(x, y)
    CondCanvas.ReSize(width, 1000)
    CondCanvas.Debug(mod.Config.Debug)
    CondCanvas.Init()

    local rectCfg = config.CondRect
    if not condConfig.UseDefaultRectStyle then
        rectCfg = condConfig.Rect
    end
    CondCanvas.Rect(rectCfg, ratio)
    if #ms > 0 then
        local fontCfg = config.FontStyle
        if not condConfig.UseDefaultFontStyle then
            fontCfg = condConfig.FontStyle
        end

        local msg = table.concat(ms, ": ")
        if isActivate and condType == CONST.EnemyConditionType.Poison then
            local current = cond._StockValueActive
            if current > 0 then
                s = {}
                if config.ShowCondValue then
                    s[#s+1] = string.format("%0.1f", current)
                end
                if config.ShowCondMaxValue then
                    if config.ShowCondValue then
                        s[#s+1] = "/"
                    end
                    local max = cond._StockValueActiveLimit
                    s[#s+1] = string.format("%d", math.ceil(max))
                end
                msg = msg .. " " .. table.concat(s, "")
            end
        end
        CondCanvas.Text(fontCfg, msg)
    end

    CondCanvas.End()

    return true
end

local Ctx_ConditionModule = Core.TypeField("app.cEnemyContext", "Conditions")
local ConditionModule_Conditions = Core.TypeField("app.cEmModuleConditions", "_Conditions")

---@param ctx EnemyContext
function _M.DrawEnemyConditions(ctx, x, y) -- cEnemyContext
    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local config = theme.Condition
    if not config.Enable then
        return x, y
    end
    if not config.AlwaysShow then
        if config.OnlyInBattle and not IsInBattle then
            return x, y
        end
    end

    local condModule = Ctx_ConditionModule:get_data(ctx)
    if not condModule then
        return x, y
    end

    -- app.cEnemyActivateValueBase[], app.cEnemyBadConditionStun etc
    local conds = ConditionModule_Conditions:get_data(condModule)
    if not conds then
        return x, y
    end

    x = x + config.OffsetX
    y = y + config.OffsetY

    local displayIndex = 0
    local col = config.Columns
    local barHeight = config.Height
    local rowHeight = barHeight + config.RowMargin
    if config.ShowCondName or config.ShowCondLevel or config.ShowCondValue or config.ShowCondMaxValue then
        rowHeight = rowHeight + condRowTextHeight
    end
    local margin = config.ColumnMargin
    local width = math.floor((config.Width - (col - 1) * margin) / col)

    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local themeConfig = theme.Condition

    -- mod.RecordCost("EnemyCond.ForEach", function ()
    Data.UpdateConditions(ctx, conds)
    LastErrs = {}
    for _, cond in pairs(Data.Enemy_Conds[ctx]) do
        if not cond then
            goto continue
        end
        local data = Data.Cond_CondData[cond]
        if data and data.Reason then
            table.insert(LastErrs, data.Reason)
        end
        if not data or not data.condType then
            goto continue
        end
        local condName = CONST.EnemyConditionTypeNames[data.condType]
        local condConfig = themeConfig.Conditions[condName]
        if not condConfig or not condConfig.Enable then
            goto continue
        end

        local colIndex, yCount, condX, condY
        colIndex = (displayIndex % col)
        yCount = math.floor(displayIndex / col)
        condX = x + colIndex * (width + margin) -- - 120
        condY = y + yCount * rowHeight
        local shown = _M.DrawEnemyCondition(ctx, cond, condX, condY, width, data, themeConfig, condConfig)
        if shown then
            displayIndex = displayIndex + 1
        end
        ::continue::
    end
    -- end, true)

    if displayIndex > 0 then
        y = y + (math.ceil(displayIndex / col)) * rowHeight
    end

    return x, y
end

local function GetEnemyPartType(id, partIndex)
    if Data.Em_PartsIndexMap[id] then
        return Data.Em_PartsIndexMap[id][partIndex]
    else
        return nil
    end
end

local PartCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})
local ScarTextCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})

function _M.DrawEnemyPart(ctx, partIndex, x, y, width, height, isSeverable, isBreakable)
    local data = Data.EnemyPartsData[ctx][partIndex]
    if not data then return end
    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local config = theme.Part

    -- local partType = data.PartType
    local partType = GetEnemyPartType(ctx:get_EmID(), partIndex)
    if not partType then return end

    local partName = CONST.EnemyPartsTypeNames[partType]
    local partConfig = config.Parts[partName]
    if not partConfig or not partConfig.Enable then return end

    local current = math.ceil(data.HP)
    local max = math.ceil(data.MaxHP)
    if max <= 0 then
        max = 999999
        if current <= 0 then
            return false
        end
    end
    if current >= 9998 and max >= 9998 and (max - current) < 2 then
        return
    end

    if config.HideHigherThanMaxHpPart then
        local monsterMaxHP = OverlayData.EnemyInfo[ctx].MaxHP
        if max > monsterMaxHP then
            return
        end
    end

    local alwaysShow = config.AlwaysShow or partConfig.AlwaysShow
    local isAlwaysShowBreakblePart = false
    if isSeverable and config.SeverableAlwaysShow then
        isAlwaysShowBreakblePart = true
    elseif isBreakable and config.BreakableAlwaysShow then
        isAlwaysShowBreakblePart = true
    end
    if isAlwaysShowBreakblePart then
        if config.BrokenNoAlwaysShow and Data.EM_BreakablePartsCache[ctx] and Data.EM_BreakablePartsCache[ctx].Broken[tostring(partIndex)] == true then
            -- broken, don't always show
        else
            alwaysShow = true
        end
    end
    -- Check should display
    if not alwaysShow then
        if current == max or current <= 0 then
            return false
        end
    end

    if _M.PartUpdateTimestampCache[ctx] == nil then
        _M.PartUpdateTimestampCache[ctx] = {}
    end

    local interval = config.AutoHideSeconds
    local currentTime = QuestElapsedTime
    if _M.PartUpdateTimestampCache[ctx][partType] == nil then
        _M.PartUpdateTimestampCache[ctx][partType] = {
            LastChangedTimestamp = -1,
            LastVal = -1,
        }
    end

    -- Check auto hide
    local hideTimer = nil
    if config.AutoHide and not alwaysShow then
        if _M.PartUpdateTimestampCache[ctx][partType].LastVal ~= current then
            _M.PartUpdateTimestampCache[ctx][partType].LastVal = current
            _M.PartUpdateTimestampCache[ctx][partType].LastChangedTimestamp = currentTime
        else
            hideTimer = currentTime - _M.PartUpdateTimestampCache[ctx][partType].LastChangedTimestamp
            if hideTimer > interval then
                -- skip unchanged
                return false
            end
        end
    end

    -- Display
    local ratio = current / max
    
    local s = {}
    if config.ShowPartName then
        s[#s+1] = partConfig.DisplayName
    end
    if config.ShowPartLevel then
        s[#s+1] = string.format("[%d]", data.Count)
    end
    if config.ShowPartName or config.ShowPartLevel then
        if config.ShowPartHP or config.ShowPartMaxHP then
            s[#s+1] = ": "
        end
    end
    if config.ShowPartHP then
        s[#s+1] = string.format("%0.1f", current)
    end

    if config.ShowPartMaxHP then
        if config.ShowPartHP then
            s[#s+1] = "/"
        end
        s[#s+1] = string.format("%d", max)
    end

    -- if isSeverable then
    --     s[#s+1] = " SEVERABLE"
    -- elseif isBreakable then
    --     s[#s+1] = " BREAKABLE"
    -- end
    -- if Data.EM_BreakablePartsCache[ctx].Broken[tostring(partIndex)] then
    --     s[#s+1] = " BROKEN"
    -- end
    if mod.Config.Debug then
        s[#s+1] = " - Hide: " .. Core.FloatFixed1(hideTimer)
        s[#s+1] = " - " .. Core.FloatFixed1(ratio * 100) .. "%"
    end

    PartCanvas.RePos(x, y)
    PartCanvas.ReSize(width, 1000)
    PartCanvas.Debug(mod.Config.Debug)
    PartCanvas.Init()
    -- local PartDiv = Div.new()
    -- PartDiv:RePos(x, y)
    -- PartDiv:ReSize(width, height)
    -- PartDiv.display = "flex"
    -- PartDiv.flexDirection = "column"
    -- PartDiv.justifyContent = "space-between"
    -- PartDiv.alignItems = "flex-start"

    -- local PartHeaderDiv = Div.new()
    -- PartHeaderDiv.display = "flex"
    -- PartHeaderDiv.flexDirection = "row"
    -- PartHeaderDiv.justifyContent = "space-between"
    -- PartHeaderDiv.alignItems = "center"
    -- PartHeaderDiv.width = PartDiv.width
    -- local PartBarDiv = Div.new()
    -- local PartScarsDiv = Div.new()
    -- PartScarsDiv.display = "flex"
    -- PartScarsDiv.flexDirection = "row"
    -- PartScarsDiv.justifyContent = "space-between"
    -- PartScarsDiv.display = "flex-start"

    -- PartDiv:add(PartHeaderDiv)
    -- PartDiv:add(PartBarDiv)
    -- PartDiv:add(PartScarsDiv)

    -- -- PartDiv.verticalDirection = "bottom-to-top"
    -- PartDiv.autoBreak = false

    local fontCfg = config.FontStyle
    if not partConfig.UseDefaultFontStyle then
        fontCfg = partConfig.FontStyle
    end

    local rectCfg = config.PartRect
    if not partConfig.UseDefaultPartStyle then
        rectCfg = partConfig.Rect
    end
    PartCanvas.Rect(rectCfg, ratio)
    
    -- local rectDiv = Div.new()
    -- rectCfg.Width = width
    -- rectDiv.renderer = Draw.RectRenderer(rectCfg, ratio)
    -- PartBarDiv:add(rectDiv)

    local partMsg = table.concat(s,"")
    if partMsg ~= "" then
        PartCanvas.Text(fontCfg, partMsg)
        -- local nameDiv = Div.new()
        -- nameDiv.width = "auto"
        -- nameDiv.renderer = Draw.TextRenderer(fontCfg, partMsg)
        -- PartHeaderDiv:add(nameDiv)
    end

    if isSeverable then
        if config.ShowSeverableIcon then
            PartCanvas.Image({
                BlockRenderX = false,
                BlockRenderY = false,
                OffsetY = fontCfg.OffsetY,
                RightAlign = true,
                Width = partRowTextHeight,
                Height = partRowTextHeight,
                MarginX = 0,
            }, SeverableIcon)
            -- local imageDiv = Div.new()
            -- imageDiv.renderer = Draw.ImageRenderer({
            --     BlockRenderX = false,
            --     BlockRenderY = false,
            --     OffsetY = fontCfg.OffsetY,
            --     RightAlign = true,
            --     Width = partRowTextHeight,
            --     Height = partRowTextHeight,
            --     MarginX = 0,
            -- }, SeverableIcon)
            -- PartHeaderDiv:add(imageDiv)
        end
    elseif isBreakable then
        if config.ShowBreakableIcon then
            PartCanvas.Image({
                BlockRenderX = false,
                BlockRenderY = false,
                OffsetY = fontCfg.OffsetY,
                RightAlign = true,
                Width = partRowTextHeight,
                Height = partRowTextHeight,
                MarginX = 0,
            }, BreakableIcon)
            -- local imageDiv = Div.new()
            -- imageDiv.renderer = Draw.ImageRenderer({
            --     BlockRenderX = false,
            --     BlockRenderY = false,
            --     OffsetY = fontCfg.OffsetY,
            --     RightAlign = true,
            --     Width = partRowTextHeight,
            --     Height = partRowTextHeight,
            --     MarginX = 0,
            -- }, BreakableIcon)
            -- PartHeaderDiv:add(imageDiv)
        end
    end

    local scarConfig = config.Scar
    if not partConfig.UseDefaultScarStyle then
        scarConfig = partConfig.Scar
    end
    if scarConfig.Enable then
        local ringCfg = config.ScarRing
        if not partConfig.UseDefaultScarStyle then
            ringCfg = partConfig.ScarRing
        end

        local lvTextCfg = config.ScarLevelText
        if not partConfig.UseDefaultScarLevelFontStyle then
            lvTextCfg = partConfig.ScarLevelText
        end

        for _, scarData in pairs(data.Scars) do
            local state = scarData.State
            -- 0 Normal 1 Tear 2 Raw
            if state < 0 or state > 2 then
                goto continue
            end
            
            local color = scarConfig.NormalColor
            local current = 0
            local max = 1
            local count = 0
            if state == 0 then
                current, max = scarData.Normal.HP, scarData.Normal.MaxHP
                count = scarData.Normal.Count
            elseif state == 1 then
                current, max = scarData.Tear.HP, scarData.Tear.MaxHP
                count = scarData.Tear.Count
                color = scarConfig.TearColor
            elseif state == 2 then
                current, max = scarData.Raw.HP, scarData.Raw.MaxHP
                count = scarData.Raw.Count
                color = scarConfig.RawColor
            end

            if scarData.IsRide then
                if not scarConfig.ShowRideScar then
                    goto continue;
                end
                if scarConfig.UseSpecialRideScarColor then
                    color = scarConfig.RideColor
                end
            end
            if scarData.IsLegendary then
                if not scarConfig.ShowLegendaryScar then
                    goto continue;
                end
                if scarConfig.UseSpecialLegendaryScarColor then
                    color = scarConfig.LegendaryColor
                end
            end

            if max <= 0 then
                max = 999999
            end

            local scarRatio = current/max

            ringCfg.Color = color
            local x, y = PartCanvas.NextPos()
            local _, _, _, _, _, _, w, h = PartCanvas.Circle(ringCfg, scarRatio)
            -- local ringDiv = Div.new()
            -- ringDiv.renderer = Draw.CircleRenderer(ringCfg, scarRatio)
            -- PartScarsDiv:add(ringDiv)
        
            
            if ringCfg.Enable and lvTextCfg.Enable then
                ScarTextCanvas.RePos(x, y)
                ScarTextCanvas.ReSize(w, h)
                ScarTextCanvas.Init()
                ScarTextCanvas.Text(lvTextCfg, tostring(count))
                ScarTextCanvas.End()
            end

            ::continue::
        end
    end

    PartCanvas.End()

    return true
    -- return PartDiv
end

function _M.DrawEnemyParts(ctx, x, y) -- cEnemyContext
    if not ctx.Parts or not Data.EnemyPartsData[ctx] then
        return x, y
    end
    
    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local config = theme.Part
    if not config.Enable then
        return x, y
    end
    if not config.AlwaysShow then
        if config.OnlyInBattle and not IsInBattle then
            return x, y
        end
    end

    local breakParts = ctx.Parts._BreakPartsByPartsIdx
    if not breakParts then
        return x, y
    end

    x = x + config.OffsetX
    y = y + config.OffsetY

    -- local PartsDiv = Div.new()
    -- PartsDiv:RePos(x, y)
    -- PartsDiv.display = "inline"

    local len = breakParts:get_Count()

    local displayIndex = 0
    local col = config.Columns
    local barHeight = config.PartRect.Height
    local rowHeight = barHeight + config.RowMargin
    if config.ShowPartName or config.ShowPartLevel or config.ShowPartHP or config.ShowPartMaxHP
        or config.ShowBreakableIcon or config.ShowSeverableIcon then
        rowHeight = rowHeight + partRowTextHeight
    end
    if config.Scar.Enable and config.ScarRing.Enable then
        rowHeight = rowHeight + (config.ScarRing.Radius)*2
    end

    local breakableConf = Data.EM_BreakablePartsCache[ctx]
    local hasBreakable = breakableConf and breakableConf.Count > 0

    local margin = config.ColumnMargin
    local width = math.floor((config.Width - (col - 1) * margin) / col)
    for i = 0, len - 1, 1 do
        local colIndex = (displayIndex % col)

        local yCount = math.floor(displayIndex / col)

        local partX = x + colIndex * (width + margin)
        local partY = y + yCount * rowHeight

        local severable = hasBreakable and breakableConf.Severable[tostring(i)]
        if config.OnlySeverable and not severable then
            goto continue
        end
        local breakble = hasBreakable and breakableConf.Breakable[tostring(i)]
        if config.OnlyBreakable and not breakble then
            goto continue
        end
        local shown = _M.DrawEnemyPart(ctx, i, partX, partY, width, barHeight, severable, breakble)
        if shown then
            displayIndex = displayIndex + 1
        end

        -- local div = _M.DrawEnemyPart(ctx, i, partX, partY, width, 3*barHeight, severable, breakble)
        -- if div then
        --     displayIndex = displayIndex + 1
        --     div.margin.right = config.ColumnMargin
        --     div.margin.bottom = config.RowMargin
        --     if i == 0 then
        --         div:RePos(partX, partY)
        --         div.display = "flex"
        --     end
        --     PartsDiv:add(div)
        -- end

        ::continue::
    end
    if displayIndex > 0 then
        y = y + (math.ceil(displayIndex / col)) * rowHeight
    end

    -- PartsDiv:ReSize(config.Width, 3*barHeight * len / col)
    -- PartsDiv:render(mod.Config.Debug)
    return x, y
end

local ScarCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 200,
    Absolute = true,
    UseBackground = false,
})

function _M.DrawEnemyScar(ctx, scar, scarIndex, x, y, width, height)
    local data = Data.EnemyScarData[ctx][scarIndex]
    if not data then return end

    local state = scar._State
    -- 0 Normal 1 Tear 2 Raw
    if state < 0 or state > 2 then
        return
    end

    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local partIndex = scar._PartsIndex_1
    local partType = GetEnemyPartType(ctx:get_EmID(), partIndex)

    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local config = theme.Scar

    local color = config.ScarColors.NormalColor
    local current = 0
    local max = 1
    local count = 0
    if state == 0 and data.Normal then
        current, max = data.Normal.HP, data.Normal.MaxHP
        count = data.Normal.Count
    elseif state == 1 and data.Tear then
        current, max = data.Tear.HP, data.Tear.MaxHP
        count = data.Tear.Count
        color = config.ScarColors.TearColor
    elseif state == 2 and data.Raw then
        current, max = data.Raw.HP, data.Raw.MaxHP
        count = data.Raw.Count
        color = config.ScarColors.RawColor
    else
        return
    end
    if data.IsRide then
        if not config.ScarColors.ShowRideScar then
            return
        end
        if config.ScarColors.UseSpecialRideScarColor then
            color = config.ScarColors.RideColor
        end
    end
    if data.IsLegendary then
        if not config.ScarColors.ShowLegendaryScar then
            return
        end
        if config.ScarColors.UseSpecialLegendaryScarColor then
            color = config.ScarColors.LegendaryColor
        end
    end
    
    -- getActiveParts()
    -- resetCurrentStateVital()
    -- setDispName(app.cEmModuleScar.cScarParts, app.user_data.EmParamParts.cDataBase)
    -- _ParamParts

    if max <= 0 then
        max = 999999
    end
    max = math.ceil(max)

    local alwaysShow = config.AlwaysShow
    -- Check should display
    if not alwaysShow then
        if current == max or current <= 0 then
            return false
        end
    end

    if _M.ScarUpdateTimestampCache[ctx] == nil then
        _M.ScarUpdateTimestampCache[ctx] = {}
    end

    local interval = config.AutoHideSeconds
    local currentTime = QuestElapsedTime
    if _M.ScarUpdateTimestampCache[ctx][scarIndex] == nil then
        _M.ScarUpdateTimestampCache[ctx][scarIndex] = {
            LastChangedTimestamp = -1,
            LastVal = -1,
        }
    end

    -- Check auto hide
    local hideTimer = nil
    if config.AutoHide and not alwaysShow then
        if _M.ScarUpdateTimestampCache[ctx][scarIndex].LastVal ~= current then
            _M.ScarUpdateTimestampCache[ctx][scarIndex].LastVal = current
            _M.ScarUpdateTimestampCache[ctx][scarIndex].LastChangedTimestamp = currentTime
        else
            hideTimer = currentTime - _M.ScarUpdateTimestampCache[ctx][scarIndex].LastChangedTimestamp
            if hideTimer > interval then
                -- skip unchanged
                return false
            end
        end
    end

    -- Display
    local ms = {}
    local s = {}
    
    if config.ShowScarLevel then
        s[#s+1] = string.format("[%d]", tostring(count))
    end
    if config.ShowPartName and partType then
        local partName = CONST.EnemyPartsTypeNames[partType]
        local partConfig = theme.Part.Parts[partName]
        if partConfig then
            s[#s+1] = partConfig.DisplayName
        end
    end
    if config.ShowScarIndex then
        s[#s+1] = string.format("[%d]", scarIndex)
    end
    if #s > 0 then
        ms[#ms+1] = table.concat(s, "")
        s = {}
    end

    if config.ShowScarHP then
        s[#s+1] = string.format("%0.1f", current)
    end

    if config.ShowScarMaxHP then
        if config.ShowScarHP then
            s[#s+1] = "/"
        end
        s[#s+1] = string.format("%d", max)
    end

    local ratio = current / max
    if mod.Config.Debug then
        s[#s+1] = " - Hide: " .. Core.FloatFixed1(hideTimer)
        s[#s+1] = " - " .. Core.FloatFixed1(ratio * 100) .. "%"
    end
    
    if #s > 0 then
        ms[#ms+1] = table.concat(s, "")
    end

    ScarCanvas.RePos(x, y)
    ScarCanvas.ReSize(width, 1000)
    ScarCanvas.Debug(mod.Config.Debug)
    ScarCanvas.Init()

    config.ScarRect.Color = color
    ScarCanvas.Rect(config.ScarRect, ratio)
    if #ms > 0 then
        ScarCanvas.Text(config.FontStyle, table.concat(ms, ": "))
    end

    ScarCanvas.End()

    return true
    -- local ScarDiv = Div.new()
    -- -- ScarDiv:RePos(x, y)
    -- ScarDiv:ReSize(width, height)
    -- ScarDiv.verticalDirection = "bottom-to-top"
    -- ScarDiv.autoBreak = false

    -- config.ScarRect.Color = color

    -- local rectDiv = Div.new()
    -- config.ScarRect.Width = width
    -- rectDiv.renderer = Draw.RectRenderer(config.ScarRect, ratio)
    -- ScarDiv:add(rectDiv)

    -- if #ms > 0 then
    --     local nameDiv = Div.new()
    --     nameDiv.renderer = Draw.TextRenderer(config.FontStyle, table.concat(ms, ": "))
    --     ScarDiv:add(nameDiv)
    -- end

    -- return ScarDiv
end

function _M.DrawEnemyScars(ctx, x, y) -- cEnemyContext
    if not ctx.Scar or not Data.EnemyScarData[ctx] then
        return x, y
    end
    
    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    local config = theme.Scar

    if not config.Enable then
        return x, y
    end
    if not config.AlwaysShow then
        if config.OnlyInBattle and not IsInBattle then
            return x, y
        end
    end

    local scarParts = ctx.Scar._ScarParts
    if not scarParts then
        return x, y
    end
    local len = scarParts:get_Count()
    if len <= 0 then
        return x, y
    end

    x = x + config.OffsetX
    y = y + config.OffsetY

    -- local ScarsDiv = Div.new()
    -- ScarsDiv:RePos(x, y)
    -- ScarsDiv.display = "inline"

    local displayIndex = 0

    local col = config.Columns
    local barHeight = config.Height
    local rowHeight = barHeight + config.RowMargin
    if config.ShowPartName or config.ShowScarLevel or config.ShowScarIndex or config.ShowScarHP or config.ShowScarMaxHP then
        rowHeight = rowHeight + partRowTextHeight
    end
    for i = 0, len - 1, 1 do
        local margin = config.ColumnMargin
        local colIndex = (displayIndex % col)

        local yCount = math.floor(displayIndex / col)

        local width = math.floor((config.Width - (col - 1) * margin) / col)

        local partX = x + colIndex * (width + margin)
        local partY = y + yCount * rowHeight

        local shown = _M.DrawEnemyScar(ctx, scarParts:get_Item(i), i, partX, partY, width, barHeight)
        if shown then
            displayIndex = displayIndex + 1
        end
        -- local div = _M.DrawEnemyScar(ctx, scarParts:get_Item(i), i, partX, partY, width, barHeight)
        -- if div then
        --     displayIndex = displayIndex + 1
        --     div.margin.right = config.ColumnMargin
        --     div.margin.bottom = config.RowMargin
        --     ScarsDiv:add(div)
        -- end
    end
    if displayIndex > 0 then
        y = y + (math.ceil(displayIndex / col)) * rowHeight
    end

    -- ScarsDiv:ReSize(config.Width, config.Height * len / col)
    -- ScarsDiv:render(mod.Config.Debug)
    return x, y
end

---@param ctx EnemyContext
function _M.DrawHpBar(ctx, x, y, width, height, i)
    local theme = mod.Runtime.Themes[Config.ThemeIndex]

    local data = OverlayData.EnemyInfo[ctx]

    local plateX, plateY = x, y
    local plateSize = 0
    if theme.EnemyIcon.Enable then
        plateSize = theme.EnemyIcon.BackgroundSize
    end

    local barStartX = plateX + plateSize

    local captureRatio, capturable = nil, nil
    if theme.CaptureStatus.Enable then
        if Data.EnemyDyingData[ctx] then
            captureRatio = Data.EnemyDyingData[ctx].CaptureRate
            capturable = Data.EnemyDyingData[ctx].Capturable
        end
    end

    local _, nextY = OverlayDrawHp.DrawHpBar(theme, ctx, barStartX, y, width, height, i == 0, captureRatio, capturable)

    if theme.EnemyIcon.Enable then
        local enemySize = theme.EnemyIcon.EnemySize
        local enemyOffset = (plateSize - enemySize)/2
        local enemyX, enemyY = plateX + enemyOffset, plateY + enemyOffset

        Draw.Image(PlateImage, plateX, plateY, plateSize, plateSize)
        Draw.Image(TryLoadEnemyImage(ctx), enemyX, enemyY, enemySize, enemySize)        
    end

    return x + plateSize, math.max(y + plateSize, nextY)
end

function _M.DrawEnemy(ctx, i, x, y, width, height) -- cEnemyContext
    -- mod.RecordCost("HpBar", function ()
        x, y = _M.DrawHpBar(ctx, x, y, width, height, i)
    -- end, true)

    local data = OverlayData.EnemyInfo[ctx]
    if OverlayData.IsQuestHost and data.HP > 0 then
        if Config.DrawPartsFirst then
            -- mod.RecordCost("Parts", function ()
                x, y = _M.DrawEnemyParts(ctx, x, y)
            -- end, true)
            -- mod.RecordCost("Conditions", function ()
                x, y = _M.DrawEnemyConditions(ctx, x, y)
            -- end, true)
        else
            -- mod.RecordCost("Conditions", function ()
                x, y = _M.DrawEnemyConditions(ctx, x, y)
            -- end, true)
            -- mod.RecordCost("Parts", function ()
                x, y = _M.DrawEnemyParts(ctx, x, y)
            -- end, true)
        end
        -- mod.RecordCost("Scars", function ()
            x, y = _M.DrawEnemyScars(ctx, x, y)
        -- end, true)
    end

    return x, y
end

function _M.DrawEnemyContext(ctx, i, total) -- cEnemyContext
    if not ctx then return false end

    local data = OverlayData.EnemyInfo[ctx]
    if not data or not data.HP then
        return false
    end
    if Config.OnlyDamaged and data.HP == data.MaxHP then
        return false
    end

    if total > 1 and data.HP <= 0 then
        -- hide dead bar when multi targets
        return false
    end

    local x = Config.PosX + i * (Config.ColumnMargin)
    local y = Config.PosY
    local width = 1000
    local height = 1000

    mod.RecordCost("Enemy", function ()
        _M.DrawEnemy(ctx, i, x, y, width, height)
    end, true)
    return true
end

function _M.DrawEnemiesInTable(list)
    if list == nil or #list <= 0 then
        return
    end

    local total = #list

    mod.InitCost("Enemy")
    mod.InitCost("HpBar")
    mod.InitCost("Parts")
    mod.InitCost("Conditions")
    mod.InitCost("EnemyCond.ForLoop")
    mod.InitCost("EnemyCond.ForEach")
    mod.InitCost("EnemyCond.ForEach.Inside")
    mod.InitCost("EnemyCond.Calc")
    mod.InitCost("EnemyCond.PrepareData")
    mod.InitCost("EnemyCond.Draw")
    mod.InitCost("Scars")

    local displayIndex = 0
    for i = 1, total, 1 do
        local ctx = list[i]
        -- Draw.Text(400, 400, 0xffffffff, string.format("Draw Traning Area %s@%x", ctx:get_type_definition():get_full_name() ,ctx:get_address()))
        local drawn = _M.DrawEnemyContext(ctx, displayIndex, total)
        if drawn then
            displayIndex = displayIndex + 1
        end
    end

    -- if mod.Config.Debug then
    --     local ctx = Data.EnemyContexts[1]
    --     _M.DrawEnemyContext(ctx, displayIndex, total + 2)
    --     _M.DrawEnemyContext(ctx, displayIndex + 1, total + 2)
    -- end
end

function _M.DrawAll()
    if not Config.Enable then return end

    if OverlayData.IsInTraningArea then
        _M.DrawEnemiesInTable(OverlayData.TraningAreaEnemies)
        -- Draw.Text(400, 400, 0xffffffff, string.format("Draw Traning Area %d", #OverlayData.TraningAreaEnemies))
        return
    end

    IsInBattle = Core.IsInBattle()

    if Config.OnlyInBattle and not IsInBattle then
        return
    end

    -- 下面两行换成 OverlayData 里的数据就会不显示，可能是执行顺序的问题
    QuestTimeLimit = Core.GetQuestTimeLimit()
    QuestElapsedTime = Core.GetQuestElapsedTime()
    if QuestTimeLimit <= 0 then
        -- 不知道为什么，但偶尔仅本组件会没清除掉？
        -- mod.verbose("Clear due to QuestTimeLimit < 0")
        -- _M.ClearData()
        -- Data.ClearData()
        return
    end

    OverlayDrawHp.QuestTimeLimit = QuestTimeLimit
    OverlayDrawHp.QuestElapsedTime = QuestElapsedTime

    _M.DrawEnemiesInTable(Data.EnemyContexts)
end

mod.D2dRegister(function ()
    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    Core.LoadFont(theme.Condition.FontStyle.FontSize)
    Core.LoadFont(theme.Part.FontStyle.FontSize)
    Core.LoadFont(theme.Part.ScarLevelText.FontSize)
    Core.LoadFont(theme.Scar.FontStyle.FontSize)
    
    -- ElementImages["Fire"] = mod.LoadImage("icons/fire.png")
    -- ElementImages["Water"] = mod.LoadImage("icons/water.png")
    -- ElementImages["Ice"] = mod.LoadImage("icons/ice.png")
    -- ElementImages["Thunder"] = mod.LoadImage("icons/thunder.png")
    -- ElementImages["Dragon"] = mod.LoadImage("icons/dragon.png")
    BreakableIcon = mod.LoadImage("icons/breakable.png")
    SeverableIcon = mod.LoadImage("icons/severable.png")

    -- CrownImages[CONST.CrownType.Small] = mod.LoadImage("icons/crown_small.png")
    -- CrownImages[CONST.CrownType.Big] = mod.LoadImage("icons/crown_silver.png")
    -- CrownImages[CONST.CrownType.King] = mod.LoadImage("icons/crown_king.png")

    PlateImage = mod.LoadImage("enemy/plate.png")
    EnemyImageUnknown = mod.LoadImage("enemy/tex_EmIcon_EM0000_00_0_IMLM4.tex.241106027.png")
end, function ()
    if condRowTextHeight == nil then
        local theme = mod.Runtime.Themes[Config.ThemeIndex]
        _, condRowTextHeight = Draw.Measure(theme.Condition.FontStyle.FontSize, "名字TextHeight")
        _, partRowTextHeight = Draw.Measure(theme.Part.FontStyle.FontSize, "名字TextHeight")
        _, scarRowTextHeight = Draw.Measure(theme.Scar.FontStyle.FontSize, "名字TextHeight")
        LevelTextWidth, LevelTextHeight = Draw.Measure(theme.Part.ScarLevelText.FontSize, "0")
    end
    _M.DrawAll()
end, "Boss")

return _M
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

local Core = require("_CatLib")
local Debug = require("_CatLib.debug")
local CONST = require("_CatLib.const")

local mod = require("mhwilds_overlay.mod")
local Config = require("mhwilds_overlay.boss.conf")

local _M = {}

---------------------------------
-- Hooks
---------------------------------

function _M.OnQuestPlaying()
    mod.verbose("OnQuestPlaying, Clear old data...")
    _M.ClearData()
    mod.verbose("Boss Data Initing")

    local isQuest = Core.IsActiveQuest()
    if isQuest then
        -- call this every frame will leak some memory
        local browsers = Core.GetMissionManager():getAcceptQuestTargetBrowsers()
        if browsers then
            Core.ForEach(browsers, function (browser)
                local ctx = browser:get_EmContext()
                table.insert(_M.EnemyContexts, ctx)
                _M.ComplexDataCollectionTargets[ctx] = true
                mod.verbose("Add context " .. tostring(ctx))
            end)
        else
            mod.verbose("No enemy browsers")
        end
    else
        mod.verbose("No quest active")
    end
end

function _M.ClearData()
    -- mod.verbose("Boss Data Cleared")
    _M.EnemyContexts = {}
    _M.EM_BreakablePartsCache = {}
    _M.ComplexDataCollectionTargets = {}

    _M.EnemyPartsData = {}
    _M.EnemyWeakPartsData = {}
    _M.EnemyScarData = {}
    _M.EnemyDyingData = {}
    
    _M.Cond_CondTypes = {}
    _M.Enemy_Conds = {}
    _M.Cond_CondData = {}
end

---------------------------------
-- Collected Boss Data, parts, scars
---------------------------------
---@type EnemyContext[]
_M.EnemyContexts = {}
_M.EM_BreakablePartsCache = {}
---@type table<EnemyContext, boolean>
_M.ComplexDataCollectionTargets = {}

---@class EnemyScarStageData
---@field HP number
---@field MaxHP number
---@field Count number

---@class EnemyScarData
---@field Normal EnemyScarStageData
---@field Tear EnemyScarStageData
---@field Raw EnemyScarStageData
---@field State app.cEmModuleScar.cScarParts.STATE
---@field IsRide boolean
---@field IsLegendary boolean

---@class EnemyPartData
---@field HP number
---@field MaxHP number
---@field Count number
---@field Scars EnemyScarData[]
---@field ScarIndex number

---@class EnemyDyingData
---@field CaptureRate number
---@field Capturable boolean

---@type table<app.cEnemyContext, table<integer, EnemyPartData>>
_M.EnemyPartsData = {} -- EnemyContext -> index -> {current, max, scars: []}
---@type table<app.cEnemyContext, table<integer, EnemyPartData>>
_M.EnemyWeakPartsData = {}

---@return EnemyPartData
local function NewPartData()
    return {
        HP = 0,
        MaxHP = 1,
        Count = 0,
        Scars = {},
        ScarIndex = 1,
    }
end

---@type table<app.cEnemyContext, table<integer, EnemyScarData>>
_M.EnemyScarData = {} -- EnemyContext -> index -> {normal: {current, max}, tear: {current, max}, raw: {current, max}}

local BreakParts_GetCount, BreakParts_GetItem = Core.GetTypeIterateFunction("app.cEmModuleParts.cBreakParts[]")
local IntArray2_GetCount, IntArray2_GetItem = Core.GetTypeIterateFunction("System.Int32[][]")
local IntArray_GetCount, IntArray_GetItem = Core.GetTypeIterateFunction("System.Int32[]")

---@param ctx EnemyContext
function _M.InitSeverableCache(ctx)
    if _M.EM_BreakablePartsCache[ctx] ~= nil then
        return true
    end

    local partsModule = ctx.Parts
    local breakableParts = partsModule._BreakParts
    if not breakableParts then
        _M.EM_BreakablePartsCache[ctx] = false
        return false
    end

    local param = partsModule._ParamParts
    if not param then
        _M.EM_BreakablePartsCache[ctx] = false
        return false
    end

    local linkArray = param._LinkPartsIndexByBreakParts
    -- local count = partsModule:getLostPartsCount()
    local count = BreakParts_GetCount:call(breakableParts)

    local breakableIndexMap = {}
    local severableIndexMap = {}
    local brokenIndexMap = {}
    mod.verbose("Initializing Severable cache")

    -- local breakIndex = partsModule:getLostPartsIndex(0) -- 这个指向的是 cBreakParts[] get_BreakParts()
    local allBroken = true
    Core.ForEach(breakableParts, function (breakPart, breakIndex)
        local isBreak = breakPart:get_IsBreak()
        local isLostPart = breakPart:get_IsLostParts()

        local indexs = IntArray2_GetItem:call(linkArray, breakIndex)
        Core.ForEach(indexs, function(index)
            local key = tostring(index)
            if isLostPart then
                severableIndexMap[key] = true
            end
            breakableIndexMap[key] = true
            brokenIndexMap[key] = isBreak
            allBroken = allBroken and isBreak
        end, IntArray_GetCount, IntArray_GetItem)
    end, BreakParts_GetCount, BreakParts_GetItem)

    _M.EM_BreakablePartsCache[ctx] = {
        Count = count,
        Severable = severableIndexMap,
        Breakable = breakableIndexMap,
        Broken = brokenIndexMap,
        AllBroken = allBroken,
    }

    return true
end

local EnemyContext_Parts = Core.TypeField("app.cEnemyContext", "Parts")

local EmParts_BreakParts = Core.TypeField("app.cEmModuleParts", "_BreakParts")
local EmParts_ParamParts = Core.TypeField("app.cEmModuleParts", "_ParamParts")

local EmParamParts_LinkPartsIndexByBreakParts = Core.TypeField("app.user_data.EmParamParts", "_LinkPartsIndexByBreakParts")

local BreakParts_IsBreakFunc = Core.TypeMethod("app.cEmModuleParts.cBreakParts", "get_IsBreak()")


function _M.UpdatePartBreakStatus(ctx)
    if not _M.EM_BreakablePartsCache[ctx] then return end
    if _M.EM_BreakablePartsCache[ctx].AllBroken then return end

    local parts = EnemyContext_Parts:get_data(ctx)
    local breakableParts = EmParts_BreakParts:get_data(parts)
    if not breakableParts then return end

    local param = EmParts_ParamParts:get_data(parts)
    local linkArray = EmParamParts_LinkPartsIndexByBreakParts:get_data(param)
    local allBroken = true
    Core.ForEach(breakableParts, function (breakPart, breakIndex)
        local isBreak = BreakParts_IsBreakFunc:call(breakPart)

        local indexs = IntArray2_GetItem:call(linkArray, breakIndex)
        Core.ForEach(indexs, function(index)
            local key = tostring(index)
            _M.EM_BreakablePartsCache[ctx].Broken[key] = isBreak
            allBroken = allBroken and isBreak
            if allBroken == false then
                return Core.ForEachBreak
            end
        end, IntArray_GetCount, IntArray_GetItem)
        if allBroken == false then
            return Core.ForEachBreak
        end
    end, BreakParts_GetCount, BreakParts_GetItem)
    _M.EM_BreakablePartsCache[ctx].AllBroken = allBroken
end

local EnemyContext_Dying = Core.TypeField("app.cEnemyContext", "Dying")
local Dying_GetCaptureVitalRate = Core.TypeMethod("app.cEmModuleDying", "get_CaptureVitalRate()")
local Dying_GetIsEnableCapture = Core.TypeMethod("app.cEmModuleDying", "get_IsEnableCapture()")

function _M.UpdateCapture(ctx)
    local dying = EnemyContext_Dying:get_data(ctx)
    if not dying then return end
    
    local rate = Dying_GetCaptureVitalRate:call(dying)
    local capturable = Dying_GetIsEnableCapture:call(dying)

    if _M.EnemyDyingData[ctx] == nil then
        _M.EnemyDyingData[ctx] = {}
    end
    _M.EnemyDyingData[ctx].CaptureRate = rate
    _M.EnemyDyingData[ctx].Capturable = capturable
end

---------------------------------
-- Data process
---------------------------------

local GetValueHolderF_ValueFunc = Core.TypeMethod("app.cValueHolderF_R", "get_Value()")
local GetValueHolderF_DefaultValueFunc = Core.TypeMethod("app.cValueHolderF_R", "get_DefaultValue()")
local GetValueHolderF_MaxValueFunc = Core.TypeMethod("app.cValueHolderF_R", "get_MaxValue()")
local GetValueHolderF_MinValueFunc = Core.TypeMethod("app.cValueHolderF_R", "get_MinValue()")

local DamageParts_Count = Core.TypeField("app.cEmModuleParts.cDamageParts", "_Count")
local DamageParts_MaxCount = Core.TypeField("app.cEmModuleParts.cDamageParts", "_MaxCount")

local NullableSingle_HasValue = Core.TypeField("System.Nullable`1<System.Single>", "_HasValue")
local NullableSingle_Value = Core.TypeField("System.Nullable`1<System.Single>", "_Value")

---@param part app.cEmModuleParts.cDamageParts
---@return EnemyScarStageData
function _M.GetDamagePartDataAll(part)
    if not part then return nil end

    local data = {
        HP = GetValueHolderF_ValueFunc:call(part),
        Default  = GetValueHolderF_DefaultValueFunc:call(part),
        Count = DamageParts_Count:get_data(part),
        MaxCount = DamageParts_MaxCount:get_data(part),

        MaxHP = GetValueHolderF_MaxValueFunc:call(part), -- nullable
        Min = GetValueHolderF_MinValueFunc:call(part), -- nullable
    }
    if NullableSingle_HasValue:get_data(data.MaxHP) then
        data.MaxHP = NullableSingle_Value:get_data(data.MaxHP)
    else
        data.MaxHP = -1
    end

    if NullableSingle_HasValue:get_data(data.Min) then
        data.Min = NullableSingle_Value:get_data(data.Min)
    else
        data.Min = -1
    end

    return data
end

---@param part app.cEmModuleParts.cDamageParts
---@return EnemyScarStageData
function _M.GetDamagePartDataSimple(part)
    if not part then return nil end

    -- Direct has worse perf
    local data = {
        HP = GetValueHolderF_ValueFunc:call(part),
        MaxHP  = GetValueHolderF_DefaultValueFunc:call(part),
        Count = DamageParts_Count:get_data(part),
    }
    return data
end

local EnemyContext_Scar = Core.TypeField("app.cEnemyContext", "Scar")

local EmParts_DamageParts = Core.TypeField("app.cEmModuleParts", "_DmgParts")
local EmParts_WeakPointParts = Core.TypeField("app.cEmModuleParts", "_WeakPointParts")

local GetScar_ScarPartsFunc = Core.TypeMethod("app.cEmModuleScar", "get_ScarParts()")

local ScarParts_Normal = Core.TypeField("app.cEmModuleScar.cScarParts", "_Normal")
local ScarParts_Tear = Core.TypeField("app.cEmModuleScar.cScarParts", "_Tear")
local ScarParts_Raw = Core.TypeField("app.cEmModuleScar.cScarParts", "_Raw")
local ScarParts_State = Core.TypeField("app.cEmModuleScar.cScarParts", "_State")
local ScarParts_IsRideScar = Core.TypeField("app.cEmModuleScar.cScarParts", "_IsRideScar")
local ScarParts_IsLegendary = Core.TypeField("app.cEmModuleScar.cScarParts", "_IsLegendary")
local ScarParts_PartsIndex_1 = Core.TypeField("app.cEmModuleScar.cScarParts", "_PartsIndex_1")

local DamageParts_GetCount, DamageParts_GetItem = Core.GetTypeIterateFunction("app.cEmModuleParts.cDamageParts[]")
local WeakPointParts_GetCount, WeakPointParts_GetItem = Core.GetTypeIterateFunction("app.cEmModuleParts.cWeakPointParts[]")
local ScarParts_GetCount, ScarParts_GetItem = Core.GetTypeIterateFunction("app.cEmModuleScar.cScarParts[]")

_M.Em_PartsIndexMap = {}

---@param ctx EnemyContext
function _M.doUpdateEnemyCtx(ctx)
    -- mod.verbose("UpdateEnemyCtx " .. tostring(ctx))

    local theme = mod.Runtime.Themes[Config.ThemeIndex]
    if _M.EnemyPartsData[ctx] == nil then
        if _M.EnemyPartsData[ctx] == nil then
            _M.EnemyPartsData[ctx] = {}
        end
    end

    if theme.CaptureStatus.Enable then
        _M.UpdateCapture(ctx)
    end

    mod.InitCost("    Part GetDamagePartData")

    local emID = ctx:get_EmID()
    if _M.Em_PartsIndexMap[emID] == nil then
        _M.Em_PartsIndexMap[emID] = {}

        local parts = EnemyContext_Parts:get_data(ctx)
        local paramParts = parts._ParamParts._PartsArray._DataArray

        Core.ForEach(paramParts, function (param, i)
            local type = Core.FixedToEnum("app.EnemyDef.PARTS_TYPE", param._PartsType._Value)
            _M.Em_PartsIndexMap[emID][i] = type
            log.info(string.format("Enmey %d: [%d] %d", emID, i, type))
        end)
    end

    -- mod.RecordCost("    Part", function ()
    if theme.Part.Enable then
        -- mod.verbose("UpdateEnemyCtx Parts")

        local parts = EnemyContext_Parts:get_data(ctx)
        -- local partsMap = Context_PartsIndexMap[emID]
        Core.ForEach(EmParts_DamageParts:get_data(parts), function (part, i)
            -- mod.verbose("UpdateEnemyCtx Parts %d", i)
            if _M.EnemyPartsData[ctx][i] == nil then
                _M.EnemyPartsData[ctx][i] = NewPartData()
            end
            -- if partsMap[i] then
            --     _M.EnemyPartsData[ctx][i].PartType = partsMap[i]
            -- end
            -- mod.RecordCost("    Part GetDamagePartData", function()
                _M.EnemyPartsData[ctx][i].HP = GetValueHolderF_ValueFunc:call(part)
                _M.EnemyPartsData[ctx][i].MaxHP = GetValueHolderF_DefaultValueFunc:call(part)
                _M.EnemyPartsData[ctx][i].Count = DamageParts_Count:get_data(part)
                if mod.Config.Verbose then
                    local partData = _M.EnemyPartsData[ctx][i]
                    -- mod.verbose("  Parts %s/%s of %s", tostring(partData.HP), tostring(partData.MaxHP), tostring(partData.Count))
                end
            -- end, true)
        end, DamageParts_GetCount, DamageParts_GetItem)

        if _M.InitSeverableCache(ctx) then
            _M.UpdatePartBreakStatus(ctx)
        end

        -- Not showing yet
        -- Core.ForEach(EmParts_WeakPointParts:get_data(parts), function (part, i)
        --     if _M.EnemyWeakPartsData[ctx] == nil then
        --         _M.EnemyWeakPartsData[ctx] = {}
        --     end
        --     if _M.EnemyWeakPartsData[ctx][i] == nil then
        --         _M.EnemyWeakPartsData[ctx][i] = {}
        --     end
        --     -- mod.RecordCost("    Part GetDamagePartData", function()
        --         _M.EnemyWeakPartsData[ctx][i].HP = GetValueHolderF_ValueFunc:call(part)
        --         _M.EnemyWeakPartsData[ctx][i].MaxHP = GetValueHolderF_DefaultValueFunc:call(part)
        --         _M.EnemyWeakPartsData[ctx][i].Count = DamageParts_Count:get_data(part)
        --     -- end, true)
        -- end, WeakPointParts_GetCount, WeakPointParts_GetItem)
    end
    -- end)

    -- mod.RecordCost("    Scar", function ()
    if theme.Scar.Enable or theme.Part.Scar.Enable then
        -- mod.verbose("UpdateEnemyCtx Scars")

        local scar = EnemyContext_Scar:get_data(ctx)

        -- for k, v in pairs(_M.EnemyPartsData[ctx]) do
        --     if _M.EnemyPartsData[ctx][k].ScarIndex == nil then
        --         _M.EnemyPartsData[ctx][k].ScarIndex = 1
        --     end
        -- end

        mod.InitCost("    Scar GetDamagePartData")
        mod.InitCost("    Scar GetDamagePartDataDirect")
        mod.CostCompare("    Scar GetDamagePartDataDirect", "    Scar GetDamagePartData")

        Core.ForEach(GetScar_ScarPartsFunc:call(scar), 
        ---@param scarParts app.cEmModuleScar.cScarParts
        function (scarParts, i)
            if _M.EnemyScarData[ctx] == nil then
                _M.EnemyScarData[ctx] = {}
            end
            if _M.EnemyScarData[ctx][i] == nil then
                _M.EnemyScarData[ctx][i] = {}
                _M.EnemyScarData[ctx][i].IsRide = ScarParts_IsRideScar:get_data(scarParts)
                _M.EnemyScarData[ctx][i].IsLegendary = ScarParts_IsLegendary:get_data(scarParts)

                local partIndex = ScarParts_PartsIndex_1:get_data(scarParts)
                -- local partType = nil
                -- if Context_PartsIndexMap[ctx][i] then
                --     partType = Context_PartsIndexMap[ctx][i]
                -- end
                if _M.EnemyPartsData[ctx][partIndex] == nil then
                    _M.EnemyPartsData[ctx][partIndex] = NewPartData()
                end
                -- _M.EnemyPartsData[ctx][partIndex].PartType = partType
                if _M.EnemyPartsData[ctx][partIndex] then
                    _M.EnemyPartsData[ctx][partIndex].Scars[_M.EnemyPartsData[ctx][partIndex].ScarIndex] = _M.EnemyScarData[ctx][i]
                    _M.EnemyPartsData[ctx][partIndex].ScarIndex = _M.EnemyPartsData[ctx][partIndex].ScarIndex + 1
                end
            end

            local state = ScarParts_State:get_data(scarParts)
            _M.EnemyScarData[ctx][i].State = state
            -- mod.RecordCost("    Scar GetDamagePartData", function()
                if state == 0 then
                    _M.EnemyScarData[ctx][i].Normal = _M.GetDamagePartDataSimple(ScarParts_Normal:get_data(scarParts))
                elseif state == 1 then
                    _M.EnemyScarData[ctx][i].Tear = _M.GetDamagePartDataSimple(ScarParts_Tear:get_data(scarParts))
                elseif state == 2 then
                    _M.EnemyScarData[ctx][i].Raw = _M.GetDamagePartDataSimple(ScarParts_Raw:get_data(scarParts))
                end
            -- end, true)
        end, ScarParts_GetCount, ScarParts_GetItem)
    end
    -- end)
end

---@param ctx EnemyContext
function _M.UpdateEnemyCtx(ctx)
    if not _M.ComplexDataCollectionTargets[ctx] then return end

    -- mod.RecordCost("BossComplexUpdate", function ()
        _M.doUpdateEnemyCtx(ctx)
    -- end)
end

local BadCond_CondType = Core.TypeField("app.cEnemyBadCondition", "_ConditionType")
local TrapCond_CondType = Core.TypeField("app.cEnemyTrapCondition", "_Condition")

---@class CondData
---@field condType app.EnemyDef.CONDITION|boolean
---@field isActivate boolean
---@field max number
---@field current number
---@field ratio number
---@field count number|nil
---@field condConfig table

---@type table<app.cEnemyActivateValueBase, app.EnemyDef.CONDITION>
_M.Cond_CondTypes = {}
---@type table<EnemyContext, app.cEnemyActivateValueBase[]>
_M.Enemy_Conds = {}
---@type table<app.cEnemyActivateValueBase, CondData>
_M.Cond_CondData = {}

---@param cond app.cEnemyActivateValueBase
---@return app.EnemyDef.CONDITION|boolean
function _M.GetCondType(cond)
    if _M.Cond_CondTypes[cond] ~= nil then
        return _M.Cond_CondTypes[cond]
    end

    local type = cond:get_type_definition()
    local typename = type:get_name()

    local condType = false
    if type:is_a("app.cEnemyBadCondition") then
        condType = BadCond_CondType:get_data(cond)
    elseif type:is_a("app.cEnemyTrapCondition") then
        condType = TrapCond_CondType:get_data(cond)
    elseif typename == "cEnemyTiredCondition" then
        condType = CONST.EnemyConditionType.Tired
    elseif typename == "cEnemyAngryCondition" then
        condType = CONST.EnemyConditionType.Angry
    end
    -- todo: fix unknown

    _M.Cond_CondTypes[cond] = condType
    return condType
end

local ValueBase_Value = Core.TypeField("app.cEnemyActivateValueBase", "_Value")
local ValueBase_IsActive = Core.TypeMethod("app.cEnemyActivateValueBase", "get_IsActive()")
local ValueBase_GetValue = Core.TypeMethod("app.cEnemyActivateValueBase", "get_Value()")
local ValueBase_GetValueRate = Core.TypeMethod("app.cEnemyActivateValueBase", "get_ValueRate()")
local ValueBase_GetLimit = Core.TypeMethod("app.cEnemyActivateValueBase", "get_LimitValue()")
local ValueBase_GetActivateTime = Core.TypeMethod("app.cEnemyActivateValueBase", "get_ActivateTime()")
local ValueBase_GetCurrentTimer = Core.TypeMethod("app.cEnemyActivateValueBase", "get_CurrentTimer()")

local BadCond_Count = Core.TypeField("app.cEnemyBadCondition", "_Count")
local TrapCond_Count = Core.TypeField("app.cEnemyTrapCondition", "_Count")

---@param cond app.cEnemyActivateValueBase
---@return CondData
local function doUpdateEnemyActivateValueBase(cond)
    if not cond then return end
    -- if not cond then return {Reason = "Nil Cond"} end

    local condType = _M.GetCondType(cond)
    if not condType then return end
    -- if not condType then return {Reason = string.format("Type %s Unknown CondType", cond:get_type_definition():get_full_name())} end

    local isActivate, max, current, ratio, count

    -- local val = ValueBase_Value:get_data(cond) -- cond._Value -- app.cValueHolderF
    isActivate = ValueBase_IsActive:call(cond) -- cond:get_IsActive()

    if isActivate then
        max = math.ceil(ValueBase_GetActivateTime:call(cond))
        current = max - ValueBase_GetCurrentTimer:call(cond)
        ratio = current / max -- get_ValueRate == 1 if activated
    else
        if condType == CONST.EnemyConditionType.Tired then
            current = cond:get_Stamina()
            max = math.ceil(cond:get_DefaultStamina())
        else
            current = math.ceil(ValueBase_GetValue:call(cond))
            max = math.ceil(ValueBase_GetLimit:call(cond))
            if max <= 0 then
                max = 1
            end
        end
    
        -- ratio = current / max
        ratio = ValueBase_GetValueRate:call(cond)
    end

    -- if mod.Config.Debug and current <= 0 then
    --     current = max /2
    --     ratio = 0.5
    -- end

    -- if themeConfig.ShowCondLevel then
        -- local type = cond:get_type_definition()
        -- local typename = type:get_name()
        -- if type:is_a("app.cEnemyBadCondition") then
        --     count = BadCond_Count:get_data(cond)
        -- elseif type:is_a("app.cEnemyTrapCondition") then
        --     count = TrapCond_Count:get_data(cond)
        -- end
        count = cond._Count
    -- end

    local data = {
        condType = condType,
        isActivate = isActivate,
        max = max,
        current = current,
        ratio = ratio,
        count = count,
    }
    _M.Cond_CondData[cond] = data
    return data
end

-- mod.OnPreUpdateBehavior(function ()
--     mod.InitCost("UpdateEnemyActivateValueBase")
-- end)

function _M.UpdateEnemyActivateValueBase(cond)
    local data
    -- mod.RecordCost("UpdateEnemyActivateValueBase", function ()
        data = doUpdateEnemyActivateValueBase(cond)
    -- end, true)
    return data
end

local Conds_GetCount, Conds_GetItem = Core.GetTypeIterateFunction("app.cEnemyActivateValueBase[]")

function _M.UpdateConditions(ctx, conds)
    if not _M.Enemy_Conds[ctx] then
        local list = {}
        Core.ForEach(conds, function (cond, i)
            table.insert(list, cond)
            _M.Cond_CondData[cond] = _M.UpdateEnemyActivateValueBase(cond)
        end, Conds_GetCount, Conds_GetItem)

        _M.Enemy_Conds[ctx] = list
    end

    for _, cond in pairs(_M.Enemy_Conds[ctx]) do
        local data = _M.Cond_CondData[cond]
        -- if not data or data.isActivate then
        -- if not data or data.isActivate or math.abs(data.current - data.max) < 0.1 then
            -- 和血量一样，更新慢了一拍，因此 isActivate 一直是 false 了
            -- 但是为什么会慢一拍呢？
            _M.Cond_CondData[cond] = _M.UpdateEnemyActivateValueBase(cond)
        -- end
    end
end

return _M
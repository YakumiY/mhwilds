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
local thread = thread

local Core = require("_CatLib")
local Draw = require("_CatLib.draw")
local CONST = require("_CatLib.const")

local mod = require("mhwilds_overlay.mod")
local OverlayData = require("mhwilds_overlay.data")
local BossData = require("mhwilds_overlay.boss.data")
local DpsChartData = require("mhwilds_overlay.dps_chart.data")
local ReporterData = require("mhwilds_overlay.reporter.data")

local HitCache = {
    LastAttacker = nil,
    LastEnemy = nil,

    LastRider = nil,
}

local DMG_CACHE = {}
local Host_TeammateDamagePacket = {}
local Host_TeammatePreCalcDamage = {}

local function ClearData()

    -- -- DMG_CACHE[ctx][dmg]
    -- local have = false
    -- for ctx, data in pairs(DMG_CACHE) do
    --     local name = Core.GetEnemyName(ctx:get_EmID())
    --     local count = Core.GetTableSize(data)
    --     Core.SendMessage("%s: %d dmgs unknown", name, count)
    --     for dmg, count in pairs(data) do
    --         Core.SendMessage("%d= %d *%d", dmg*count, dmg, count)
    --         have = true
    --     end
    -- end
    -- if not have then
    --     Core.SendMessage("无未知记录")
    -- end
    DMG_CACHE = {}
    Host_TeammateDamagePacket = {}
    Host_TeammatePreCalcDamage = {}
end

---@param enemyCtx EnemyContext
---@return boolean
local function ShouldRecord(enemyCtx)
    local data = OverlayData.EnemyInfo[enemyCtx]

    -- Update enemy info
    if data == nil then
        data = {}
        OverlayData.EnemyInfo[enemyCtx] = data
    end

    if not data.ACCESS_KEY then
        local browser = enemyCtx:get_Browser()
        local accessKey = browser:get_ThisTargetAccessKey()
        local isTarget = OverlayData.IsTarget(accessKey)

        data.ACCESS_KEY = accessKey
        data.IsTarget = isTarget
        OverlayData.EnemyInfo[enemyCtx] = data
    end

    -- check conditions
    if not data.IsTarget then
        HitCache.LastAttacker = nil
        HitCache.LastEnemy = nil

        return false
    end

    if data.HP and data.HP <= 0 then
        HitCache.LastAttacker = nil
        HitCache.LastEnemy = nil

        return false
    end

    return true
end

-- mod.HookFunc("app.EnemyCharacter", "evDamage_Health(System.Single, System.Single)", function (args)
--     if true then
--         return
--     end
--     local dmg = sdk.to_float(args[3])
--     if dmg <= 0 then
--         return
--     end

--     local this = Core.ToEnemyCharacter(args[2])
--     local ctx = this._Context._Em
--     if ShouldRecord(ctx) then
--         if DMG_CACHE[ctx] and DMG_CACHE[ctx][dmg] then
--             DMG_CACHE[ctx][dmg] = DMG_CACHE[ctx][dmg] - 1
--             if DMG_CACHE[ctx][dmg] <= 0 then
--                 DMG_CACHE[ctx][dmg] = nil
--             end
--         else
--             if mod.Config.Debug then
--                 Core.SendMessage("DMG: " .. Core.FloatFixed1(dmg) .. " at " .. Core.GetEnemyName(ctx:get_EmID()))
--             end
--         end
--     end
-- end)

---@param attacker Hunter | Otomo
---@param enemyCtx EnemyContext
---@param condType app.EnemyDef.CONDITION
---@param value number
local function UpdateStatusDamage(attacker, enemyCtx, condType, value)
    if not condType or not value or value < 0 then
        return
    end

    OverlayData.UpdateStatusDamage(attacker, enemyCtx, condType, value)
end

local LAST_CONDITION = CONST.EnemyConditionType.Ryuki

mod.HookFunc("app.cEnemyBadConditionPoison", "stockActive(System.Single)", function (args)
    if not HitCache.LastAttacker or not HitCache.LastEnemy then
        return
    end

    ---@type app.cEnemyBadCondition
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local condType = this._ConditionType -- EnemyDef.CONDITION
    if not condType or condType ~= CONST.EnemyConditionType.Poison then return end

    local enemy = this._Character
    if not enemy then return end
    if HitCache.LastEnemy ~= enemy._Context._Em then return end

    local val = sdk.to_float(args[3])
    if val <= 0 then
        return
    end
    
    local max = this._StockValueActiveLimit -1
    if max <= 0 then
        return
    end
    local current = this._StockValueActive
    local remain = max - current

    local diff = val
    if diff > remain then
        diff = remain
    end

    UpdateStatusDamage(HitCache.LastAttacker, HitCache.LastEnemy, condType, diff)
end)

local StabbingEnemyCtx = nil
local IsStabbing = false
mod.HookFunc("app.cEnemyBadConditionSkillStabbing", "onActivate()", function (args)
    if not HitCache.LastAttacker or not HitCache.LastEnemy then
        return
    end
    ---@type app.cEnemyBadCondition
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local condType = this._ConditionType -- EnemyDef.CONDITION
    if not condType then return end
    if condType < 34 or condType > 37 then
        return
    end

    StabbingEnemyCtx = this._Character._Context._Em
    IsStabbing = true
end, function (retval)
    IsStabbing = false
    StabbingEnemyCtx = nil
end)

mod.OnPreUpdateBehavior(function ()
    HitCache.LastAttacker = nil
    HitCache.LastEnemy = nil
end)

local CondNames = Core.GetEnumMap("app.EnemyDef.CONDITION")

local function UpdateBadCondition(args)
    if not HitCache.LastAttacker or not HitCache.LastEnemy then
        mod.verbose("UpdateBadCondition: LastAttacker: %s, LastEnemy: %s", tostring(HitCache.LastAttacker), tostring(HitCache.LastEnemy))
        
        ---@type app.cEnemyBadCondition
        local this = sdk.to_managed_object(args[2])
        if not this then return end
        local storage = thread.get_hook_storage()
        storage["this"] = this

        local condType = this._ConditionType -- EnemyDef.CONDITION
        local disp = tostring(condType)
        if condType then
            disp = CondNames[condType]
        end
        local val = sdk.to_float(args[3])
        mod.verbose("This: %s, CondType: %s, Value: %s", this:get_type_definition():get_full_name(), tostring(disp), tostring(val))
        return
    end

    ---@type app.cEnemyBadCondition
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    local storage = thread.get_hook_storage()
    storage["this"] = this

    -- 因为 add() 这个函数是 app.cEnemyActivateValueBase 的
    -- 所以可能是其它的类型在被调用
    local condType = this._ConditionType -- EnemyDef.CONDITION
    if not condType then return end

    local enemy = this._Character
    if not enemy then return end
    if HitCache.LastEnemy ~= enemy._Context._Em then return end

    local val = sdk.to_float(args[3])
    if val <= 0 then
        return
    end

    if this:get_IsActive() then
        return
    end

    if OverlayData.ValidCondType[condType] then
        local max = this:get_LimitValue()
        local current = this:get_Value()
        local remain = max - current

        local diff = val
        if diff > remain then
            diff = remain
        end

        if condType == CONST.EnemyConditionType.Ride then
            HitCache.LastRider = HitCache.LastAttacker
        end

        UpdateStatusDamage(HitCache.LastAttacker, HitCache.LastEnemy, condType, diff)
    end

    if mod.Config.Debug then
        local bool = sdk.to_int64(args[4]) & 1
        -- 虽然不知道为什么，但是有时候 condType == nil

        local name = Core.GetEnemyName(enemy._Context._Em:get_EmID())
        local msg = string.format("%s|%s add %0.1f %s at %s", tostring(condType), tostring(CONST.EnemyConditionTypeNames[condType]), val, tostring(bool), name)

        local accessKey = this._Invoker
        if accessKey then
            -- 虽然不知道为什么，但是在 invoker == nil 时会有奇怪的调用
            msg = msg .. string.format(" by %d/%d", accessKey.Category, accessKey.UniqueIndex)
            -- return
        end

        Core.SendMessage(msg)
    end

    -- last condition
    if this._ConditionType == LAST_CONDITION or this:get_type_definition():get_name() == "cEnemyBadConditionSkillRyuki" then
        HitCache.LastAttacker = nil
        HitCache.LastEnemy = nil
    end
end

-- local inited = false
-- mod.OnPreUpdateBehavior(function ()
--     inited = false
-- end)

mod.HookFunc("app.cEnemyBadCondition", "add(System.Single, System.Boolean)", function (args)
    -- if not inited then
    --     mod.InitCost("UpdateBadCondition")
    -- end

    -- mod.RecordCost("UpdateBadCondition", function ()
        UpdateBadCondition(args)
    -- end, true)

    -- local this = Core.Cast(args[2])
    -- local storage = thread.get_hook_storage()
    -- storage["this"] = this
    -- Core.SendMessage("addBadCond Pre: %0.2f", this:get_Value())
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    storage["this"] = nil
    if this then
        BossData.UpdateEnemyActivateValueBase(this)
        -- add 之后虽然值变了，但是 tmd 居然 IsActive == false
        -- Core.SendMessage("addBadCond Post: %0.2f, isActive: %s", this:get_Value(), tostring(this:get_IsActive()))
    end
    return retval
end)

---@param attacker Hunter | Otomo
---@param enemyCtx EnemyContext
---@param isPlayer boolean
---@param totalDamage number|nil
local function InitDamageRecord(attacker, enemyCtx, isPlayer, totalDamage)
    if not ShouldRecord(enemyCtx) then
        return
    end

    if attacker and enemyCtx then
        HitCache.LastAttacker = attacker
        HitCache.LastEnemy = enemyCtx
    end

    -- totalDamage cache
    if enemyCtx and totalDamage and totalDamage > 0 then
        if DMG_CACHE[enemyCtx] == nil then
            DMG_CACHE[enemyCtx] = {}
        end
        if DMG_CACHE[enemyCtx][totalDamage] == nil then
            DMG_CACHE[enemyCtx][totalDamage] = 0
        end
    end

    OverlayData.InitDamageRecord(attacker, enemyCtx, isPlayer, totalDamage)
    DpsChartData.InitDamageRecord(attacker, enemyCtx, isPlayer, totalDamage)
end

---@param enemyCtx EnemyContext
---@param dmg number
---@param attacker Attacker
---@param isPlayer boolean
local function RecordFixedDamage(enemyCtx, dmg, attacker, isPlayer)
    if not dmg or dmg <= 0 or not ShouldRecord(enemyCtx) then
        return
    end
    InitDamageRecord(attacker, enemyCtx, isPlayer, dmg)
    DMG_CACHE[enemyCtx][dmg] = DMG_CACHE[enemyCtx][dmg] + 1

    if OverlayData.EnemyInfo[enemyCtx] then
        if dmg > OverlayData.EnemyInfo[enemyCtx].HP then
            dmg = OverlayData.EnemyInfo[enemyCtx].HP
        end
    end
    OverlayData.HandleFixedDamage(attacker, enemyCtx, dmg)
    DpsChartData.HandleDamage(attacker, enemyCtx, isPlayer)
end

---@param enemyCtx EnemyContext
---@param dmg number
local function RecordBlastDamage(enemyCtx, dmg)
    if not dmg or dmg <= 0 or not ShouldRecord(enemyCtx) then
        return
    end
    if DMG_CACHE[enemyCtx] == nil then
        DMG_CACHE[enemyCtx] = {}
    end
    if DMG_CACHE[enemyCtx][dmg] == nil then
        DMG_CACHE[enemyCtx][dmg] = 0
    end
    DMG_CACHE[enemyCtx][dmg] = DMG_CACHE[enemyCtx][dmg] + 1

    if OverlayData.EnemyInfo[enemyCtx] then
        if dmg > OverlayData.EnemyInfo[enemyCtx].HP then
            dmg = OverlayData.EnemyInfo[enemyCtx].HP
        end
    end
    for attacker, record in pairs(OverlayData.HunterDamageRecords) do
        if record.Blast <= 0 then
            goto continue
        end
        local ratio = record.Blast / OverlayData.QuestStats.Blast
        local sharedDmg = ratio*dmg

        local isPlayer = OverlayData.HunterInfo[attacker].IsPlayer

        InitDamageRecord(attacker, enemyCtx, isPlayer, sharedDmg)
        OverlayData.HandleBlastDamage(attacker, enemyCtx, sharedDmg)
        DpsChartData.HandleDamage(attacker, enemyCtx, isPlayer)

        ::continue::
    end
end

---@param enemyCtx EnemyContext
---@param dmg number
local function RecordPoisonDamage(enemyCtx, dmg)
    if not dmg or dmg <= 0 or not ShouldRecord(enemyCtx) then
        return
    end
    if DMG_CACHE[enemyCtx] == nil then
        DMG_CACHE[enemyCtx] = {}
    end
    if DMG_CACHE[enemyCtx][dmg] == nil then
        DMG_CACHE[enemyCtx][dmg] = 0
    end
    DMG_CACHE[enemyCtx][dmg] = DMG_CACHE[enemyCtx][dmg] + 1

    if OverlayData.EnemyInfo[enemyCtx] then
        if dmg > OverlayData.EnemyInfo[enemyCtx].HP then
            dmg = OverlayData.EnemyInfo[enemyCtx].HP
        end
    end

    for attacker, record in pairs(OverlayData.HunterDamageRecords) do
        if record.Poison <= 0 then
            goto continue
        end
        local ratio = record.Poison / OverlayData.QuestStats.Poison
        local sharedDmg = ratio*dmg

        local isPlayer = OverlayData.HunterInfo[attacker].IsPlayer

        InitDamageRecord(attacker, enemyCtx, isPlayer, sharedDmg)
        OverlayData.HandlePoisonDamage(attacker, enemyCtx, sharedDmg)
        DpsChartData.HandleDamage(attacker, enemyCtx, isPlayer)

        ::continue::
    end
end

---@param enemyCtx EnemyContext
---@param dmg number
local function RecordStabbingDamage(enemyCtx, dmg)
    if not dmg or dmg <= 0 or not ShouldRecord(enemyCtx) then
        return
    end
    if DMG_CACHE[enemyCtx] == nil then
        DMG_CACHE[enemyCtx] = {}
    end
    if DMG_CACHE[enemyCtx][dmg] == nil then
        DMG_CACHE[enemyCtx][dmg] = 0
    end
    DMG_CACHE[enemyCtx][dmg] = DMG_CACHE[enemyCtx][dmg] + 1

    if OverlayData.EnemyInfo[enemyCtx] then
        if dmg > OverlayData.EnemyInfo[enemyCtx].HP then
            dmg = OverlayData.EnemyInfo[enemyCtx].HP
        end
    end

    for attacker, record in pairs(OverlayData.HunterDamageRecords) do
        local isPlayer = OverlayData.HunterInfo[attacker].IsPlayer

        InitDamageRecord(attacker, enemyCtx, isPlayer, dmg)
        OverlayData.HandleStabbingDamage(attacker, enemyCtx, dmg)
        DpsChartData.HandleDamage(attacker, enemyCtx, isPlayer)

        ::continue::
    end
end

---@param accessKey app.TARGET_ACCESS_KEY
---@return boolean
local function GetIsPlayerFromKey(accessKey)
    local category = accessKey.Category
    return category == 0 or category == 5
end

local TargetAccessKeyUtil = Core.WrapTypedef("app.TargetAccessKeyUtil")

---@param accessKey app.TARGET_ACCESS_KEY
---@return Attacker|nil
local function GetAttackerFromKey(accessKey)
    local attacker
    local category = accessKey.Category
    local isPlayer = category == 0 or category == 5 -- 0 player 5 NPC
    if isPlayer then
        attacker = TargetAccessKeyUtil:StaticCall("getHunterCharacter(app.TARGET_ACCESS_KEY)", accessKey)
    else
        attacker = TargetAccessKeyUtil:StaticCall("getOtomoCharacter(app.TARGET_ACCESS_KEY)", accessKey)
    end
    return attacker
end

-- app.cEnemyStockDamage.cBadConditionBlastInfo
-- app.cEnemyBadConditionBlast.onActivate()

local BlastEnemyCtx = nil
mod.HookFunc("app.cEnemyBadConditionBlast", "onActivate()", function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    BlastEnemyCtx = this._Character._Context._Em
    -- local storage = thread.get_hook_storage()
    -- storage["ctx"] = BlastEnemyCtx
end, function (retval)
    BlastEnemyCtx = nil
    return retval
end)

-- mod.HookFunc("app.cEnemyStockDamage.cScarDamageInfo", "setParam(app.user_data.EmParamParts.SCAR_DAMAGE_CATEGORY, System.Nullable`1<System.Int32>, System.UInt32, via.vec3, app.TARGET_ACCESS_KEY, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Single, System.Nullable`1<System.Single>)", function (args)
--     if not BlastEnemyCtx then return end

--     local storage = thread.get_hook_storage()
--     local ctx = storage["ctx"]
--     if ctx then
--         Core.SendMessage("setParam have ctx")
--     end
--     local dmg = sdk.to_float(args[14])
--     -- if mod.Config.Debug then
--         Core.SendMessage("setParam: %0.1f", dmg)
--     -- end
--     RecordBlastDamage(BlastEnemyCtx, dmg)
-- end)

-- mod.HookFunc("app.cEnemyStockDamage.cScarDamageInfo", "setBlastParam(System.Single, System.Int32, System.UInt32, via.vec3, app.TARGET_ACCESS_KEY)", function (args)
--     if not BlastEnemyCtx then return end

--     local storage = thread.get_hook_storage()
--     local ctx = storage["ctx"]
--     if ctx then
--         Core.SendMessage("setBlastParam have ctx")
--     end
--     local dmg = sdk.to_float(args[3])
--     -- if mod.Config.Debug then
--         Core.SendMessage("setBlastParam: %0.1f", dmg)
--     -- end
--     RecordBlastDamage(BlastEnemyCtx, dmg)
-- end)

mod.HookFunc("app.cEnemyStockDamage.cBadConditionDamageInfo", "setParam(System.Single, app.TARGET_ACCESS_KEY, System.Boolean)", function (args)
    if not BlastEnemyCtx then return end

    local dmg = sdk.to_float(args[3])
    if mod.Config.Debug then
        Core.SendMessage("cBadConditionDamageInfo: %0.1f", dmg)
    end
    RecordBlastDamage(BlastEnemyCtx, dmg)
end)

local TargetAccessKeyType = Core.Typedef("app.TARGET_ACCESS_KEY")

-- 研究半天为什么伤害数值是 1.0
-- 原来他妈的没有额外伤害啊？WeakPart的生命值就tm是1.0……
-- local RequestWeakPointEnemyCtx = nil
-- mod.HookFunc("app.cEnemyStockDamage.cWeakPointDamageInfo", "setParam(System.Single, System.Boolean, app.TARGET_ACCESS_KEY)", function (args)
--     if RequestWeakPointEnemyCtx == nil then return end
--     local enemyCtx = RequestWeakPointEnemyCtx
--     RequestWeakPointEnemyCtx = nil

--     local this = sdk.to_managed_object(args[2])
--     if not this then return end
--     local targetAccessKey = sdk.to_valuetype(args[5], "app.TARGET_ACCESS_KEY")
--     Core.SendMessage("Weak attacker: %d/%d", targetAccessKey.Category, targetAccessKey.UniqueIndex)

--     local isPlayer = GetIsPlayerFromKey(targetAccessKey)

--     local attacker = GetAttackerFromKey(targetAccessKey)
--     if attacker == nil then
--         -- 到这里时没有调用 stockExternalDamage
--         Core.SendMessage("weak attacker nil: %d/%d", targetAccessKey.Category, targetAccessKey.UniqueIndex)
--         return
--     end

--     local storage = thread.get_hook_storage()
--     storage["this"] = this
--     storage["ctx"] = enemyCtx
--     storage["attacker"] = attacker
--     storage["isPlayer"] = isPlayer
-- end, function (retval)
--     local storage = thread.get_hook_storage()
--     local this = storage["this"]
--     if not this then
--         return retval
--     end
--     local dmg = this.DamageValue
--     if dmg <= 0 then
--         return retval
--     end

--     local enemyCtx = storage["ctx"]
--     local attacker = storage["attacker"]
--     local isPlayer = storage["isPlayer"]

--     -- if mod.Config.Debug then
--         Core.SendMessage("Weak Ex DMG: %0.1f", dmg)
--     -- end
--     RecordFixedDamage(enemyCtx, dmg, attacker, isPlayer)
-- end)
-- mod.HookFunc("app.cEnemyStockDamage", "stockExternalDamageWeakPoint(System.Int32, System.Single, app.TARGET_ACCESS_KEY)", function (args)
--     local this = sdk.to_managed_object(args[2])
--     if not this then return end

--     local enemyCtx = this:get_Context():get_Em()
--     local isBoss = enemyCtx:get_IsBoss()
--     if not isBoss then return end

--     RequestWeakPointEnemyCtx = enemyCtx
--     Core.SendMessage("Weak attack: %d/%0.1f", sdk.to_int64(args[3]), sdk.to_float(args[4]))
-- end)

-- Single 参数似乎是伤害比例，如缠蛙是0.3，伤口血条100，最终伤害即30
-- mod.HookFunc("app.EnemyCharacter", "requestScarBreakDamageCore(app.cEmModuleScar.cScarParts.STATE, System.Int32, System.Single, System.Boolean, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>)", function (args)
--     Core.SendMessage("ReqScarBreak DMG: %0.1f", sdk.to_float(args[5]))
-- end)

local PoisonEnemyCtx = nil
mod.HookFunc("app.cEnemyBadConditionPoison", "onUpdateActive()", function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    PoisonEnemyCtx = this._Character._Context._Em
end, function (retval)
    PoisonEnemyCtx = nil
    return retval
end)

-- 这个是包括很多 external damage，如坠落（藤蔓陷阱）等
-- 理论上 stock external damage 才是真实的对怪物造成伤害，但是区分度不够，因此不得不使用更细致的针对伤口的 scar
local RequestExternalDamage = 0
mod.HookFunc("app.cEnemyStockDamage", "stockExternalDamage(System.Single, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>)", function (args)
    RequestExternalDamage = sdk.to_float(args[3])
    if RequestExternalDamage <= 0 then
        return
    end

    if PoisonEnemyCtx and OverlayData.EnemyInfo[PoisonEnemyCtx] then
        local ctx = PoisonEnemyCtx
        local dmg = RequestExternalDamage
        PoisonEnemyCtx = nil
        RequestExternalDamage = 0

        local hp = OverlayData.EnemyInfo[ctx].HP
        if hp <= 1 then
            return
        elseif hp <= dmg then
            dmg = hp-1
        end
        RecordPoisonDamage(ctx, dmg)
        return
    end
    if IsStabbing then
        local ctx = StabbingEnemyCtx
        local dmg = RequestExternalDamage
        StabbingEnemyCtx = nil
        RequestExternalDamage = 0

        -- Core.SendMessage("Stabbing DMG: %0.1f", RequestExternalDamage)

        -- local hp = OverlayData.EnemyInfo[ctx].HP
        -- if hp <= 1 then
        --     return
        -- elseif hp <= dmg then
        --     dmg = hp-1
        -- end
        RecordStabbingDamage(ctx, dmg)
        return
    end
    if mod.Config.Debug or mod.Config.Verbose then
        mod.verbose("External DMG: %0.1f", RequestExternalDamage)
    end
end)

local PreviousExternalDamage = 0
local NullableTargetAccessKeyType = Core.Typedef("System.Nullable`1<app.TARGET_ACCESS_KEY>")
mod.HookFunc("app.cEnemyStockDamage", "stockExternalDamageScar(System.Int32, System.Single, System.Boolean, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>, System.Boolean)", function (args)
    -- 参数值：
    -- System.Int32, System.Single, System.Boolean, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>, System.Boolean
    -- 0             100(伤口生命值)    false           true            ??                                         true

    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local enemyCtx = this:get_Context():get_Em()
    local isBoss = enemyCtx:get_IsBoss()
    if not isBoss then return end

    local hasValue = sdk.get_native_field(args[7], NullableTargetAccessKeyType, "_HasValue")

    local attacker
    if not hasValue then
        if mod.Config.Debug then
            Core.SendMessage("has no value")
        end
        -- 骑乘终结居然没有，我他妈服了
        attacker = HitCache.LastRider
    else
        local targetAccessKey = sdk.get_native_field(args[7], NullableTargetAccessKeyType, "_Value")
        if mod.Config.Debug then
            local category = targetAccessKey.Category
            local index = targetAccessKey.UniqueIndex
            Core.SendMessage("Scar attacker: %d/%d", category, index)
        end
        attacker = GetAttackerFromKey(targetAccessKey)
    end

    if attacker == nil then
        if mod.Config.Debug then
            Core.SendMessage("attacker nil")
        end
        return
    end
    local isPlayer = true

    local exDmg = this:get_field("<ExternalDamage>k__BackingField")
    if exDmg > 0 then
        if enemyCtx ~= nil and attacker ~= nil and isPlayer ~= nil and exDmg >= RequestExternalDamage then
            local realDamage = RequestExternalDamage
            if mod.Config.Debug then
                Core.SendMessage("Scar Ex DMG: %0.1f", realDamage)
            end
            RecordFixedDamage(enemyCtx, realDamage, attacker, isPlayer)
        else
            if mod.Config.Debug then
                Core.SendMessage("Unknown Scar Ex DMG: %0.1f, Req: %0.1f", exDmg, RequestExternalDamage)
            end
        end
    end
    RequestExternalDamage = 0
end, function (retval)
    RequestExternalDamage = 0
    HitCache.LastRider = nil

    return retval
end)

local function GetHunterByAttackerIndex(index)
    if index <= 0 or index >= 4 then
        return nil
    end

    local mgr = Core.GetNetworkManager()
    local netMgr = mgr:get_UserInfoManager()
    local netUserInfoList = netMgr:getUserInfoList(2) -- app.Net_UserInfoList, app.net_session_manager.SESSION_TYPE
    local memberNum = netUserInfoList:get_MemberNum()

    if memberNum <= 1 then
        return nil -- Shouldn't be here
    end
    
    local userInfo = netUserInfoList._ListInfo:get_Item(index)
    if not userInfo:get_IsValid() then
        mod.verbose("GetHunterByAttackerIndex: user info at %d invalid", index)
        return
    end
    local param = userInfo.param
    local guid = Core.FormatGUID(param.HunterId)

    for hunter, data in pairs(OverlayData.HunterInfo) do
        if data.GUID == guid then
            return hunter
        end
    end
end

mod.HookFunc("app.EnemyCharacter", "receivePacket_Damage(app.net_packet.cEmDamage)", function (args)
    if not OverlayData.IsQuestHost then
        return
    end

    local damage = Core.Cast(args[3])

    Host_TeammateDamagePacket[damage] = true
end)

mod.HookFunc("app.cEnemyStockDamage.cPreCalcDamage", "fromPacket(app.net_packet.cEmDamage)",
function (args)
    if not OverlayData.IsQuestHost then
        return
    end

    local packet = Core.Cast(args[3])
    if not Host_TeammateDamagePacket[packet] then
        return
    end

    Host_TeammateDamagePacket[packet] = nil
    local this = Core.Cast(args[2])
    Host_TeammatePreCalcDamage[this] = true
end)

---@param enemyCtx EnemyContext
---@param calcDamage app.cEnemyStockDamage.cCalcDamage
---@param damageRate app.cEnemyStockDamage.cDamageRate
---@param preCalc app.cEnemyStockDamage.cPreCalcDamage
local function RecordCalcDamage(enemyCtx, calcDamage, damageRate, preCalc)
    local FinalDamage = calcDamage.FinalDamage
    if not FinalDamage or FinalDamage <= 0 then
        return
    end

    if not calcDamage then return end
    if not ShouldRecord(enemyCtx) then
        return
    end

    local Common = calcDamage.Common

    local attackerAccessKey = Common.Attacker
    if not attackerAccessKey then
        return
    end

    local attacker = GetAttackerFromKey(attackerAccessKey)
    if attacker == nil then
        return
    end
    if mod.Config.Verbose then
        mod.verbose("Attacker: %s", attacker:get_GameObject():get_Name())
    end
    local isPlayer = GetIsPlayerFromKey(attackerAccessKey)

    if OverlayData.EnemyInfo[enemyCtx] and OverlayData.EnemyInfo[enemyCtx].HP then
        if FinalDamage > OverlayData.EnemyInfo[enemyCtx].HP then
            FinalDamage = OverlayData.EnemyInfo[enemyCtx].HP
        end
    end
    InitDamageRecord(attacker, enemyCtx, isPlayer, FinalDamage)

    OverlayData.HandleCalcDamage(attacker, enemyCtx, isPlayer, calcDamage, damageRate, preCalc)
    DpsChartData.HandleDamage(attacker, enemyCtx, isPlayer)

    if attacker:get_IsMaster() then
        local isCritical
        local isPhysicalExploit = damageRate.Meat*100 >= 44.9
        local isMindEye = damageRate.Meat*100 <= 20.1
        local isElement = calcDamage.Element > 0
        local isElementExploit = isElement and damageRate.MeatElem*100 >= 19.9
        ReporterData.RecordCalcDamage(calcDamage, isPhysicalExploit, isMindEye, isElement, isElementExploit)
    end
end

-- app.cEnemyApplyDamageEntity.app.cEnemyApplyDamageEntity.<apply>g__applyScarDamage|59_1(app.cEmModuleScar.cScarParts, app.cEnemyStockDamage.cScarDamageInfo, System.Int32, app.cEnemyApplyDamageEntity.<>c__DisplayClass59_0)

local Enemy_GetHealthManager = Core.TypeMethod("app.EnemyCharacter", "get_HealthMgr")

local Enemy_ContextHolder = Core.TypeField("app.EnemyCharacter", "_Context")
local EnemyContextHolder_Context = Core.TypeField("app.cEnemyContextHolder", "_Em")

local HealthManager_GetHealth = Core.TypeMethod("app.cHealthManager", "get_Health")
local HealthManager_GetMaxHealth = Core.TypeMethod("app.cHealthManager", "get_MaxHealth")

mod.HookFunc("app.cEnemyStockDamage", "calcStockDamage(app.cEnemyStockDamage.cCalcDamage, app.cEnemyStockDamage.cPreCalcDamage, app.cEnemyStockDamage.cDamageRate)", function (args)  
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local preCalc = sdk.to_managed_object(Core.DerefPtr(args[4]))
    if not preCalc then
        return
    end

    if OverlayData.IsQuestHost then
        local attackerKey = preCalc.Common.Attacker
        if attackerKey.Category == 0 then
        local attacker = GetAttackerFromKey(attackerKey)
            if attacker ~= Core.GetPlayerCharacter() then
                if Host_TeammatePreCalcDamage[preCalc] ~= true then
                    return
                end
                Host_TeammatePreCalcDamage[preCalc] = nil
            end
        end
    end

    local attacker = preCalc.Common.Attacker
    local category = attacker.Category
    if not (category == 0 or category == 2 or category == 5) then
        return
    end
    if preCalc.Attack <= 0 and preCalc.FixAttack <= 0 and preCalc.AttrValue <= 0 then
        return
    end

    local enemyCtx = this:get_Context():get_Em()
    local isBoss = enemyCtx:get_IsBoss()
    if not isBoss then return end

    local storage = thread.get_hook_storage()
    storage["this"] = this
    storage["ctx"] = enemyCtx
    storage["dmg_ref"] = args[3]
    storage["pre_calc"] = preCalc
    storage["dmg_rate"] = sdk.to_managed_object(Core.DerefPtr(args[5]))
end, function (retval)
    local storage = thread.get_hook_storage()
    local ctx = storage["ctx"]
    local ref = storage["dmg_ref"]
    local damageRate = storage["dmg_rate"]
    local preCalc = storage["pre_calc"]

    storage["this"] = nil
    storage["ctx"] = nil
    storage["dmg_ref"] = nil
    storage["pre_calc"] = nil
    storage["dmg_rate"] = nil

    if ref == nil or ctx == nil or damageRate == nil or preCalc == nil then
        return
    end

    local ptr = Core.DerefPtr(ref)
    -- mod.verbose("CalcPtr %d", ptr)
    local calcDamage = sdk.to_managed_object(ptr) -- :add_ref()
    if calcDamage then
        RecordCalcDamage(ctx, calcDamage, damageRate, preCalc)
    end
    calcDamage = nil

    -- local this = storage["this"]
    -- if this then
    --     local chara = this:get_Character()
        
    --     local ctxHolder = Enemy_ContextHolder:get_data(chara)
    --     local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
    --     local hpMgr = Enemy_GetHealthManager:call(chara)
    --     local hp = HealthManager_GetHealth:call(hpMgr)
    --     mod.verbose("Calc: %0.2f", hp)
    -- end
    return retval
end)

---@param attacker Hunter | Otomo
---@param enemyCtx EnemyContext
---@param hitInfo app.HitInfo
---@param attackData app.cAttackParamPl | app.cAttackParamOt -- app.cAttackParamBase
---@param damageData app.cDamageParamEm -- app.cDamageParamBase
local function RecordHitData(attacker, enemyCtx, hitInfo, attackData, damageData, isPlayer)
    if not ShouldRecord(enemyCtx) then
        return
    end

    local totalDamage = damageData.FinalDamage
    if totalDamage <= 0 then
        return
    end
    InitDamageRecord(attacker, enemyCtx, isPlayer, totalDamage)

    -- Update hit count
    OverlayData.HandleHitData(attacker, enemyCtx, hitInfo, attackData, damageData, isPlayer)

    if attacker:get_IsMaster() then
        ReporterData.RecordHitInfo(attackData._CriticaType == CONST.CriticalType.Critical, attackData._CriticaType == CONST.CriticalType.Negative)
    end
    -- Core.SendMessage("_UseSkillAdditionalDamage: %s", tostring(attackData._UseSkillAdditionalDamage))
    -- Core.ForEach(attackData._SkillAdditinalDamageArray._Array, function (additional)
    --     ReporterData.RecordSkillAdditionalDamage(additional._SkillType, additional._Damage)
    -- end)
    -- if attackData._IsStealthAttack then
    --     Core.SendMessage("StealthAttack")
    -- end

    if totalDamage and totalDamage > 0 then
        DMG_CACHE[enemyCtx][totalDamage] = DMG_CACHE[enemyCtx][totalDamage] + 1
    end
end

mod.HookFunc("app.HunterCharacter", "evHit_AttackPostProcess(app.HitInfo)",
function(args)
    ---@type app.HitInfo
    local hitInfo = sdk.to_managed_object(args[3])
    local damageData = hitInfo:get_DamageData()
    -- cDamageParamBase （实际上是 cDamageParamOt 打到猫 cDamageParamEm Boss 打到怪 打到鸟是nil）
    if damageData == nil or damageData:get_type_definition():get_name() ~= "cDamageParamEm" then return end
    local FinalDmg = damageData:get_field("FinalDamage")
    if FinalDmg <= 0 then
        return
    end

    local damageOwner = hitInfo:get_DamageOwner()
    -- local AttackObj = hitInfo:get_AttackObj() -- app.Weapon, etc
    -- local DamageObj = hitInfo:get_DamageObj() -- app.EnemyEntityManager, etc
    ---@type Hunter
    local hunter = sdk.to_managed_object(args[2])

    ---@type Enemy
    local enemy = damageOwner:getComponent(Core.Typeof("app.EnemyCharacter"))
    if enemy == nil then return end

    local enemyContextHolder = enemy._Context
    if enemyContextHolder == nil then
        return nil
    end

    local enmeyContext = enemyContextHolder._Em
    if not enmeyContext:get_IsBoss() then
        return
    end

    local attackData = hitInfo:get_AttackData() -- get_AttackData() -- cAttackParamBase （实际上是 cAttackParamPl）

    RecordHitData(hunter, enmeyContext, hitInfo, attackData, damageData, true)
end)

mod.HookFunc("app.OtomoCharacter", "evHit_AttackPostProcess(app.HitInfo)",
function(args)
    ---@type app.OtomoCharacter
    local otomo = sdk.to_managed_object(args[2])

    ---@type app.HitInfo
    local hitInfo = sdk.to_managed_object(args[3])
    local damageData = hitInfo:get_DamageData()
    -- cDamageParamBase （实际上是 cDamageParamOt 打到猫 cDamageParamEm Boss 打到怪 打到鸟是nil）
    if damageData == nil or damageData:get_type_definition():get_name() ~= "cDamageParamEm" then return end
    local FinalDmg = damageData:get_field("FinalDamage")
    if FinalDmg <= 0 then
        return
    end

    local damageOwner = hitInfo:get_DamageOwner()

    ---@type app.EnemyCharacter
    local enemy = damageOwner:getComponent(Core.Typeof("app.EnemyCharacter"))
    if enemy == nil then return end

    local enemyContextHolder = enemy._Context
    if enemyContextHolder == nil then
        return nil
    end

    local enmeyContext = enemyContextHolder._Em
    if not enmeyContext:get_IsBoss() then
        return
    end

    local attackData = hitInfo:get_AttackData() -- get_AttackData() -- cAttackParamBase （实际上是 cAttackParamOt）

    RecordHitData(otomo, enmeyContext, hitInfo, attackData, damageData, false)
end)

mod.HookFunc("app.Wp10Insect", "evAttackPostProcess(app.HitInfo)",
function(args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    if not this:get_Hunter():get_IsMaster() then return end

    local hitInfo = sdk.to_managed_object(args[3])
    local damageData = hitInfo:get_DamageData()
    -- cDamageParamBase （实际上是 cDamageParamOt 打到猫 cDamageParamEm Boss 打到怪 打到鸟是nil）
    if damageData == nil or damageData:get_type_definition():get_name() ~= "cDamageParamEm" then return end
    local FinalDmg = damageData:get_field("FinalDamage")
    if FinalDmg <= 0 then
        return
    end
end)

-- -- stockDamageNet(app.net_packet.cEmDamage)
-- -- 这玩意可能是房主用的
-- mod.HookFunc("app.EnemyCharacter", "receivePacket_Damage(app.net_packet.cEmDamage)", function (args)
--     local this = Core.Cast(args[2]) -- 这个 this 为什么是 app.cEnemyStockDamage ???

--     -- local enemyContextHolder = enemy._Context
--     -- if enemyContextHolder == nil then
--     --     Core.SendMessage("Type: %s", enemy:get_type_definition():get_full_name())
--     --     local obj = enemy:get_GameObject()
--     --     local name = obj:get_Name()
--     --     Core.SendMessage("No enemy ctx holder: %s", name)
--     --     return nil
--     -- end

--     local enemyCtx = this:get_Context():get_Em() -- enemyContextHolder._Em
--     if not enemyCtx:get_IsBoss() then
--         Core.SendMessage("No enemy boss")
--         return
--     end

--     mod.verbose("receivePacket_Damage")
    
--     local damage = Core.Cast(args[3])

--     if mod.Config.Verbose then
--         local Msg = ""
    
--         Msg = Msg .. string.format("AttackerIndex: %d, PartsIndex: %d, DamageType: %d/%d/%d, ActionType: %d\n", damage.AttackerIndex, damage.PartsIndex, damage.DamageType, damage.DamageTypeCustom, damage.EmDamageType, damage.ActionType)
    
--         Msg = Msg .. string.format("Attack: %0.2f, FixAttack: %0.2f, Heal: %0.2f, AttackAttr: %d, AttrValue: %0.2f, AttackCond: %d, CondValue: %0.2f", damage.Attack, damage.FixAttack, damage.Heal, damage.AttackAttr, damage.AttrValue, damage.AttackCond, damage.CondValue)

--         mod.verbose(Msg)
--         Core.SendMessage(Msg)
--     end
    
--     local FinalDamage = damage.Attack
--     if FinalDamage <= 0 then
--         Core.SendMessage("No damage")
--         return
--     end

--     local attackerIndex = damage.AttackerIndex
--     local attacker = GetHunterByAttackerIndex(attackerIndex)
    
--     local Physical = 0
--     local Fixed = 0
--     local Elemental = 0

--     if damage.AttackAttr > 0 and damage.AttackAttr <= 5 then
--         Elemental = damage.AttrValue
--     end
--     if damage.ActionType == 0 then
--         Fixed = FinalDamage - Elemental
--     else
--         Physical = FinalDamage - Elemental
--     end
--     Core.SendMessage("%0.2f = %0.2f + %0.2f + %0.2f", FinalDamage, Physical, Elemental, Fixed)

--     InitDamageRecord(attacker, enemyCtx, true, FinalDamage)
--     -- Update quest data
--     OverlayData.QuestStats.Total = OverlayData.QuestStats.Total + FinalDamage
--     OverlayData.QuestStats.Physical = OverlayData.QuestStats.Physical + Physical
--     OverlayData.QuestStats.Elemental = OverlayData.QuestStats.Elemental + Elemental
--     OverlayData.QuestStats.Fixed = OverlayData.QuestStats.Fixed + Fixed
--     -- debuffs

--     -- Update per player data
--     local data = OverlayData.HunterDamageRecords[attacker]
--     data.Total = data.Total + FinalDamage
--     data.Physical = data.Physical + Physical
--     data.Elemental = data.Elemental + Elemental
--     data.Fixed = data.Fixed + Fixed

--     OverlayData.HunterDamageRecords[attacker] = data

--     -- Update per player per enemy data
--     local data = OverlayData.HunterEnemyDamageRecords[attacker][enemyCtx]
--     data.Total = data.Total + FinalDamage
--     data.Physical = data.Physical + Physical
--     data.Elemental = data.Elemental + Elemental
--     data.Fixed = data.Fixed + Fixed

--     OverlayData.HunterEnemyDamageRecords[attacker][enemyCtx] = data

--     -- Update per enemy data
--     local data = OverlayData.EnemyDamageRecords[enemyCtx]
--     data.Total = data.Total + FinalDamage
--     data.Physical = data.Physical + Physical
--     data.Elemental = data.Elemental + Elemental
--     data.Fixed = data.Fixed + Fixed

--     OverlayData.EnemyDamageRecords[enemyCtx] = data
-- end)

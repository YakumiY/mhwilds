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
local Draw = require("_CatLib.draw")
local CONST = require("_CatLib.const")
local Action = require("_CatLib.action")

local mod = require("mhwilds_overlay.mod")

local _M = {}

function _M.ClearData()
    -- if _M.Damage then
    --     local sum = 0
    --     for key, dmg in pairs(_M.Damage) do
    --         mod.verbose("TotalDamage %s: %0.2f", key, dmg)
    --         sum = sum + dmg
    --     end
    --     mod.verbose("TotalDamage Sum: %0.2f", sum)
    -- end

    _M.EvHitDamage = 0
    _M.Damage = {}
    _M.StockDamage = {}
end

_M.ClearData()

local function IsDevMode()
    return mod.Config.Debug or mod.Config.Verbose
end

if not IsDevMode() then
    return _M
end

function _M.DebugHook(typename, methodName, preHook, postHook)
    mod.HookFunc(typename, methodName, function (args)
        if not IsDevMode() then
            return
        end
        mod.verbose("=Start %s:%s", typename, methodName)
        mod.indent()
        if preHook then
            mod.verbose("=StartPreHook %s:%s", typename, methodName)
            local ret = preHook(args)
            mod.verbose("=EndPreHook %s:%s", typename, methodName)
            return ret
        end
    end, function (retval)
        if not IsDevMode() then
            return retval
        end
        if postHook then
            mod.verbose("=StartPostHook %s:%s", typename, methodName)
            local ret = postHook(retval)
            mod.verbose("=EndPostHook %s:%s", typename, methodName)
            if ret ~= nil then
                retval = ret
            end
        end

        mod.deindent()
        mod.verbose("=End %s:%s", typename, methodName)
        return retval
    end)
end

local NpcUtil = Core.WrapTypedef("app.NpcUtil")

local CRITICAL = Core.GetEnumMap("app.Hit.CRITICAL_TYPE")

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

---@param hunter Hunter
local function GetHunterName(hunter)
    if not hunter then
        return "NIL_HUNTER"
    end
    if not hunter.get_HunterExtend then
        return "NO_HUNTER "..hunter:get_type_definition():get_full_name()
    end
    local hunterExtend = hunter:get_HunterExtend()
    local isNPC = hunterExtend:get_IsNpc()
    if isNPC then
        local npcCtxHolder = hunterExtend:get_field("_ContextHolder") -- cNpcContextHolder
        local npcCtx = npcCtxHolder:get_Npc()
        return NpcUtil:StaticCall("getNpcName(app.NpcDef.ID)", npcCtx.NpcID)
    else
        local playerCtxHolder = hunterExtend:get_field("_ContextHolder") -- cPlayerContextHolder
        local playerCtx = playerCtxHolder:get_Pl()
        local playerName = playerCtx:get_PlayerName()
        return playerName
    end
end

-- app.cEnemyStockDamage.stockDamageDetail(app.HitInfo)

local function GetHunterByAttackerIndex(index)
    if index <= 0 or index >= 4 then
        return nil
    end

    local mgr = Core.GetPlayerManager()
    if not mgr then
        return
    end

    local info = mgr:call("findPlayer_MemberIndex(System.Int32, app.net_session_manager.SESSION_TYPE)", index, 2)
    if info then
        return info:get_Character()
    end
end

---@param packet app.net_packet.cEmDamage
local function LogPacketEmDamage(packet)
    if not mod.Config.Verbose then
        return
    end

    mod.indent()
    local Msg = "Packet_EmDamage"

    mod.verbose("AttackerIndex: %d, PartsIndex: %d, DamageType: %d/%d/%d, ActionType: %d", packet.AttackerIndex, packet.PartsIndex, packet.DamageType, packet.DamageTypeCustom, packet.EmDamageType, packet.ActionType)

    mod.verbose("Attack: %0.2f, FixAttack: %0.2f, Heal: %0.2f, AttackAttr: %d, AttrValue: %0.2f, AttackCond: %d, CondValue: %0.2f", packet.Attack, packet.FixAttack, packet.Heal, packet.AttackAttr, packet.AttrValue, packet.AttackCond, packet.CondValue)

    mod.verbose("StunDamage: %0.2f, StaminaDamage: %0.2f, RideDamage: %0.2f, RidingScarDamage: %0.2f, RidingSuccessDamage: %0.2f, SkillAdditionalDamage: %0.2f", packet.StunDamage, packet.StaminaDamage, packet.RideDamage, packet.RidingScarDamage, packet.RidingSuccessDamage, packet.SkillAdditionalDamage)

    mod.verbose("PartsBreakRate: %0.2f, TearScarCreateRate: %0.2f, TearScarRate: %0.2f, RawScarRate: %0.2f, OldScarRate: %0.2f, FromEmRate: %0.2f, GmSleepRate: %0.2f", packet.PartsBreakRate, packet.TearScarCreateRate, packet.TearScarRate, packet.RawScarRate, packet.OldScarRate, packet.FromEmRate , packet.GmSleepRate)

    mod.verbose("Kireaji: %d, ScarIndex: %d, ScarDamageCategory: %d", packet.Kireaji, packet.ScarIndex, packet.ScarDamageCategory)
    
    mod.deindent()
end

_M.DebugHook("app.cEnemyStockDamage", "stockDamageDetail(app.HitInfo)", function (args)
    mod.verbose("Stock Damage")
    local this = Core.Cast(args[2])
    local storage = Core.HookStorage()
    storage["this"] = this
end, function (retval)
    local storage = Core.HookStorage()
    local this = storage["this"]
    storage["this"] = nil
    if not this then
        return
    end

    local Print = false
    local records = this:get_PlayerDamage()

    local stockDamage = {}

    Core.ForEach(records, function (record, i)
        if stockDamage[i+1] == nil then
            stockDamage[i+1] = 0
        end
        stockDamage[i+1] = record.Damage
        if record.Damage > 0 then
            Print = true
        end
    end)

    if Print then
        for i, dmg in pairs(stockDamage) do
            mod.verbose("StockDamage %d: %0.2f", i, dmg)
        end
    end
end)

_M.DebugHook("app.EnemyCharacter", "receivePacket_Damage(app.net_packet.cEmDamage)", function (args)

end)

-- _M.DebugHook("app.mcShellColHit", "evAttackPreProcess(app.HitInfo)",
-- function(args)
--     ---@type app.HitInfo
--     local hitInfo = sdk.to_managed_object(args[3])

--     local storage = Core.HookStorage()
--     storage["hitInfo"] = hitInfo
-- end, function (retval)
--     local storage = Core.HookStorage()
--     local hitInfo = storage["hitInfo"]
--     storage["hitInfo"] = nil
--     if not hitInfo then
--         return
--     end
--     if mod.Config.Verbose then
--         _M.LogHitInfo(hitInfo)
--     end
-- end)

-- _M.DebugHook("app.HunterCharacter", "evHit_AttackPreProcess(app.HitInfo)",
-- function(args)
--     ---@type app.HitInfo
--     local hitInfo = sdk.to_managed_object(args[3])

--     if mod.Config.Verbose then
--         _M.LogHitInfo(hitInfo)
--     end
-- end)

_M.DebugHook("app.HunterCharacter", "evHit_AttackPostProcess(app.HitInfo)",
function(args)
    ---@type app.HitInfo
    local hitInfo = sdk.to_managed_object(args[3])

    if mod.Config.Verbose then
        _M.LogHitInfo(hitInfo)
    end
end)

_M.DebugHook("app.cEnemyStockDamage", "calcStockDamage(app.cEnemyStockDamage.cCalcDamage, app.cEnemyStockDamage.cPreCalcDamage, app.cEnemyStockDamage.cDamageRate)", function (args)  
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local preCalc = sdk.to_managed_object(Core.DerefPtr(args[4]))
    if not preCalc then
        return
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
        _M.LogCalcDamage(calcDamage, damageRate, preCalc)
    end
    calcDamage = nil
end)

_M.DebugHook("app.EnemyCharacter", "evHit_Damage(app.HitInfo)",
function (args)
    -- mod.verbose("Eval Damage hook")
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local storage = thread.get_hook_storage()
    storage["this"] = this
    storage["args"] = args
    if mod.Config.Verbose and args then
        local hitinfo = Core.Cast(args[3])
        _M.LogHitInfo(hitinfo, false, true)
    end
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    storage["this"] = nil
    if not this then
        return retval
    end

    -- local args = storage["args"]
    -- if mod.Config.Verbose and args then
    --     local hitinfo = Core.Cast(args[3])
    --     _M.LogHitInfo(hitinfo, true)
    -- end
end)

_M.DebugHook("app.cEnemyStockDamage.cPreCalcDamage", "toPacket(app.cEnemyContextHolder)",
function (args)
    local this = Core.Cast(args[2])
    
end, function (retval)
    local packet = Core.Cast(retval)
    mod.verbose("AttackerIndex at [%d]: %s sending packet...", packet.AttackerIndex, GetHunterName(Core.GetPlayerCharacter()))
    
    LogPacketEmDamage(packet)
end)

_M.DebugHook("app.cEnemyStockDamage.cPreCalcDamage", "fromPacket(app.net_packet.cEmDamage)",
function (args)
    local packet = Core.Cast(args[3])

    local attackerIndex = packet.AttackerIndex
    local hunter = GetHunterByAttackerIndex(attackerIndex)
    if not hunter then
        mod.verbose("AttackerIndex at [%d]: is nil", attackerIndex)
        return
    end

    local actionClass = ""
    if hunter then
        local baseActionController = hunter:get_BaseActionController()
        local action = baseActionController:get_CurrentAction()
        actionClass = action:get_type_definition():get_name()
    end

    mod.verbose("AttackerIndex at [%d]: %s (%s) receiving packet...", attackerIndex, GetHunterName(hunter), actionClass)
    
    LogPacketEmDamage(packet)
end)

_M.DebugHook("app.cEnemyStockDamage", "stockDamageNet(app.net_packet.cEmDamage)", function (args)
    mod.verbose("stockDamageNet")
end, function (retval)
    
end)

-- 伤害如何计算的
-- 伤害的计算在Enemy侧，分为三个阶段：
-- 阶段1：PreCalc。该阶段中，传递攻击者（Index）、命中的位置（vec3）、伤害类型、动作类型（斩打弹无）、动作值、属性值、斩味、异常、伤口的伤害倍率 等信息
--  作为单机，PreCalc 直接进行计算。直接hook Hunter 的 evHit PostProcess，和 Enemy 的 calcStockDamage 即可
--  作为客机，PreCalc 会通过 toPacket 函数发包给主机。虽然本地还会进行计算，但是一切数据据观察都是不准确的，例如打点（肉质）、是否会心，等等。
--  作为主机，将接收其他人传来的 PreCalc（通过 fromPacket 函数解包）。
-- 阶段2：DamageRate。该阶段计算各种倍率，如肉质、属性吸收、斩味倍率、伤口倍率、各种异常倍率，等等。
--  其中仅就肉质/属性吸收和斩味倍率而言，由于 PreCalc 中含有 parts index/scar index，是可以提前计算出来的。
--  实在不行，调用一次 app.cEnemyStockDamage.calcDamageRate(app.cEnemyStockDamage.cDamageRate, app.cEnemyStockDamage.cPreCalcDamage, System.Nullable`1<System.Int32>) 即可计算出来
-- 阶段3：CalcDamage。伤害计算完毕，得出 FinalDamage。

-- 作为房主：
-- 作为房主时，其他客机的行动将在 PreCalc 阶段后直接执行一次。
-- 但是此时，部分动作，如龙杭炮等，CalcStockDamage 计算得出的 FinalDamage 均为 0。原理尚未知，但是记住结论：Replica 的部分动作无法计算出伤害。
-- 后续房主将会从 fromPacket 以及后续的 CalcStockDamage 得到真实非 0 的 FinalDamage。
-- 这就导致，其他动作会被计算两遍，而唯有龙杭炮等只计算了一遍。

-- 作为客机：
-- 作为客机时，由于收不到龙杭炮的伤害，也无法收取到其他人的真实伤害信息，因此，龙杭炮等伤害将永久丢失。

-- -- 这玩意可能是房主用的
-- _M.DebugHook("app.EnemyCharacter", "receivePacket_Damage(app.net_packet.cEmDamage)", function (args)
--     if not mod.Config.Verbose then
--         return
--     end

--     local damage = Core.Cast(args[3])

--     local Msg = ""

--     Msg = Msg .. string.format("AttackerIndex: %d, PartsIndex: %d, DamageType: %d/%d/%d, ActionType: %d\n", damage.AttackerIndex, damage.PartsIndex, damage.DamageType, damage.DamageTypeCustom, damage.EmDamageType, damage.ActionType)

--     Msg = Msg .. string.format("Attack: %0.2f, FixAttack: %0.2f, Heal: %0.2f, AttackAttr: %d, AttrValue: %0.2f, AttackCond: %d, CondValue: %0.2f", damage.Attack, damage.FixAttack, damage.Heal, damage.AttackAttr, damage.AttrValue, damage.AttackCond, damage.CondValue)

--     mod.verbose(Msg)
-- end)

local Enemy_GetHealthManager = Core.TypeMethod("app.EnemyCharacter", "get_HealthMgr")

local Enemy_ContextHolder = Core.TypeField("app.EnemyCharacter", "_Context")
local EnemyContextHolder_Context = Core.TypeField("app.cEnemyContextHolder", "_Em")

local HealthManager_GetHealth = Core.TypeMethod("app.cHealthManager", "get_Health")
local HealthManager_GetMaxHealth = Core.TypeMethod("app.cHealthManager", "get_MaxHealth")

-- mod.HookFunc("app.cEnemyStockDamage", "stockDamageDetail(app.HitInfo)", function (args)
--     if not mod.Config.Verbose then
--         return
--     end
--     local this = sdk.to_managed_object(args[2])
--     local storage = thread.get_hook_storage()
--     storage["this"] = this
--     local chara = this:get_Character()
    
--     local ctxHolder = Enemy_ContextHolder:get_data(chara)
--     local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
--     local hpMgr = Enemy_GetHealthManager:call(chara)
--     local hp = HealthManager_GetHealth:call(hpMgr)
--     mod.verbose("PreStock: HP: %0.2f", hp)

--     -- _M.LogHitInfo(Core.Cast(args[3]))
-- -- end, function (retval)
-- --     if not mod.Config.Verbose then
-- --         return
-- --     end
-- --     local storage = thread.get_hook_storage()
-- --     local this = storage["this"]
-- --     if not this then return end

-- --     local chara = this:get_Character()
    
-- --     local ctxHolder = Enemy_ContextHolder:get_data(chara)
-- --     local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
-- --     local hpMgr = Enemy_GetHealthManager:call(chara)
-- --     local hp = HealthManager_GetHealth:call(hpMgr)
-- --     mod.verbose("PostStock: %0.2f", hp)
-- end)

-- evDamage_Health(System.Single) 只在单人有用
-- mod.HookFunc("app.EnemyCharacter", "evHit_Damage(app.HitInfo)",
-- function (args)
--     -- mod.verbose("Eval Damage hook")
--     local this = sdk.to_managed_object(args[2])
--     if not this then return end

--     local storage = thread.get_hook_storage()
--     storage["this"] = this
--     storage["args"] = args
-- end, function (retval)
--     local storage = thread.get_hook_storage()
--     local this = storage["this"]
--     if not this then
--         return retval
--     end

--     if mod.Config.Verbose then
--         local ctxHolder = Enemy_ContextHolder:get_data(this)
--         local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
--         local hpMgr = Enemy_GetHealthManager:call(this)
--         local hp = HealthManager_GetHealth:call(hpMgr)
--         local maxHp = HealthManager_GetMaxHealth:call(hpMgr)
        
--         local args = storage["args"]
--         local hitInfo = Core.Cast(args[3])
--         local damageData = hitInfo:get_DamageData()
--         mod.verbose("evHit_Damage DamageDataType: %s", damageData:get_type_definition():get_full_name())
--         if damageData == nil or damageData:get_type_definition():get_name() ~= "cDamageParamEm" then return end
--         local FinalDmg = damageData:get_field("FinalDamage")

--         _M.EvHitDamage = _M.EvHitDamage + FinalDmg
--         mod.verbose("evHit_Damage: HP: %0.2f/%0.2f, totalDmg: %0.2f, %0.2f", hp, maxHp, _M.EvHitDamage, _M.EvHitDamage + hp)
--     end
-- end)

-- -- evDamage_Health(System.Single) 只在单人/房主有用
-- mod.HookFunc("app.EnemyCharacter", "evDamage_Health(System.Single, System.Single)",
-- function (args)
--     -- mod.verbose("Eval Damage hook")
--     local this = sdk.to_managed_object(args[2])
--     if not this then return end

--     local storage = thread.get_hook_storage()
--     storage["this"] = this
-- end, function (retval)
--     local storage = thread.get_hook_storage()
--     local this = storage["this"]
--     if not this then
--         return retval
--     end

--     local ctxHolder = Enemy_ContextHolder:get_data(this)
--     local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
--     local hpMgr = Enemy_GetHealthManager:call(this)
--     local hp = HealthManager_GetHealth:call(hpMgr)
--     mod.verbose("evDamage_Health: HP: %0.2f", hp)
-- end)

-- -- evDamage_Health(System.Single) 只在单人有用
-- mod.HookFunc("app.EnemyCharacter", "evDamage(app.EnemyDef.Damage.cApplyEventParam)",
-- function (args)
--     -- mod.verbose("Eval Damage hook")
--     local this = sdk.to_managed_object(args[2])
--     if not this then return end

--     local storage = thread.get_hook_storage()
--     storage["this"] = this
-- end, function (retval)
--     local storage = thread.get_hook_storage()
--     local this = storage["this"]
--     if not this then
--         return retval
--     end

--     local ctxHolder = Enemy_ContextHolder:get_data(this)
--     local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
--     local hpMgr = Enemy_GetHealthManager:call(this)
--     local hp = HealthManager_GetHealth:call(hpMgr)
--     mod.verbose("evDamage: %0.2f", hp)
-- end)

-- mod.HookFunc("app.cEnemyStockDamage", "update()", function (args)
--     if not mod.Config.Verbose then
--         return
--     end
--     local this = Core.Cast(args[2])
--     local storage = Core.HookStorage()
--     storage["this"] = this
-- end, function (retval)
--     local storage = Core.HookStorage()
--     local this = storage["this"]
--     if not this then
--         return
--     end

--     local Print = true
--     local records = this:get_PlayerDamage()
--     Core.ForEach(records, function (record, i)
--         if _M.StockDamage[i] == nil then
--             _M.StockDamage[i] = 0
--         end
--         _M.StockDamage[i] = _M.StockDamage[i] + record.Damage
--         if record.Damage > 0 then
--             Print = true
--         end
--     end)

--     if Print then
--         for i, dmg in pairs(_M.StockDamage) do
--             mod.verbose("StockDamage %d: %0.2f", i, dmg)
--         end
--     end
-- end)

function _M.LogHitInfo(hitInfo, shouldRecord, logZeroAtk)
    if not mod.Config.Verbose then
        return
    end
    if not hitInfo then
        mod.verbose("HitInfo: nil")
        return
    end

    local attackOwner = hitInfo:get_AttackOwner()
    local actualAttackOwner = hitInfo:getActualAttackOwner()
    local hunter = actualAttackOwner:getComponent(Core.Typeof("app.HunterCharacter"))
    if not hunter then
        return
    end

    local damageData = hitInfo:get_DamageData()
    -- cDamageParamBase （实际上是 cDamageParamOt 打到猫 cDamageParamEm Boss 打到怪 打到鸟是nil）
    if damageData == nil or damageData:get_type_definition():get_name() ~= "cDamageParamEm" then return end
    mod.verbose("DamageDataType: %s", damageData:get_type_definition():get_full_name())
    local FinalDmg = damageData:get_field("FinalDamage")

    local AttackIndex = hitInfo:get_AttackIndex() -- UserDataIndex -- has Resource Index

    local attackName = attackOwner:get_Name()
    local actualAttackName = actualAttackOwner:get_Name()

    local actionId = string.format("%d/%d", AttackIndex._Resource, AttackIndex._Index)
    local actionName = ""
    local actionClass = ""
    actualAttackName = GetHunterName(hunter)
    if hunter:get_IsMaster() then
        local name = Action.GetActionNameByHitInfo(hitInfo)
        if name then
            actionName = string.format("(%s)", name)
        end
    end

    local baseActionController = hunter:get_BaseActionController()
    local action = baseActionController:get_CurrentAction()
    actionClass = action:get_type_definition():get_name()
    
    local msg = string.format("%s of %s uses action %s %s/(%s): %0.2f", attackName, actualAttackName, actionId, actionName, actionClass, FinalDmg)
    mod.verbose(msg)

    -- via.GameObject
    local attackOwner = hitInfo:getActualAttackOwner()
    local attackName = attackOwner:get_Name()
    local damageOwner = hitInfo:get_DamageOwner()
    -- local AttackObj = hitInfo:get_AttackObj() -- app.Weapon, etc
    -- local DamageObj = hitInfo:get_DamageObj() -- app.EnemyEntityManager, etc

    if shouldRecord then
        if _M.Damage[attackName] == nil then
            _M.Damage[attackName] = 0
        end
        _M.Damage[attackName] = _M.Damage[attackName] + FinalDmg
        -- local sum = 0
        -- for key, dmg in pairs(_M.Damage) do
        --     mod.verbose("TotalDamage %s: %0.2f", key, dmg)
        --     sum = sum + dmg
        -- end
        -- mod.verbose("TotalDamage Sum: %0.2f", sum)
    end
    

    local attackData = hitInfo:get_AttackData() -- get_AttackData() -- cAttackParamBase （实际上是 cAttackParamPl）

    local Atk = attackData:get_field("_Attack")
    if Atk <= 1.0 and logZeroAtk then
        mod.verbose("Zero Attack HitInfo")
        if Core.StringContains(attackName, "Shell") then
            mod.verbose("Zero Attack Shell HitInfo")
        end
    end
    local FixAtk = attackData:get_field("_FixAttack")
    local AttrAtk = attackData:get_field("_AttrValue")
    local OgAtk = attackData:get_field("_OriginalAttack")
    local Critical = attackData._CriticaType
    local CriticalStr = CRITICAL[Critical]
    if Critical == nil then
        mod.verbose("Critical is nil, type: %s", attackData:get_type_definition():get_full_name())
    end

    local AttackMsg = string.format("%s: %0.2f(FinalDmg)|%s(%s)=%0.2f(Attack)", attackName, FinalDmg, tostring(Critical), tostring(CriticalStr), Atk)
    if AttrAtk > 0 then
        AttackMsg = AttackMsg .. string.format("+%0.2f(ElemAttack)", AttrAtk)
    end
    if FixAtk > 0 then
        AttackMsg = AttackMsg .. string.format("+%0.2f(FixAttack)", FixAtk)
    end
    AttackMsg = AttackMsg .. string.format("/%0.2f(OriginAttack)", OgAtk)

    AttackMsg = AttackMsg .. ", "

    if attackData._IsNoCritical then
        AttackMsg = AttackMsg .. "IsNoCritical, "
    end
    if attackData._IsNoUseKireaji then
        AttackMsg = AttackMsg .. "IsNoUseKireaji, "
    end
    if damageData.IsHitWeakPoint_Parts then
        AttackMsg = AttackMsg .. "IsHitWeakPoint_Parts, "
    end
    if damageData.IsHitWeakPoint_Scar then
        AttackMsg = AttackMsg .. "IsHitWeakPoint_Scar, "
    end

    if attackData:get_type_definition():is_a("app.cAttackParamPl") then
        AttackMsg = AttackMsg .. string.format("ScarDamageRate: %0.1f/%0.1f/%0.1f", attackData._TearScarDamageRate, attackData._RawScarDamageRate, attackData._OldScarDamageRate)
    end

    local AttackResIdxMsg = tostring(AttackIndex:get_field("_Resource")) .. "/" .. tostring(AttackIndex:get_field("_Index"))
    mod.verbose(AttackMsg .. " || Action: " .. AttackResIdxMsg)
end

function _M.LogCalcDamage(calcDamage, damageRate, preCalc)
    -- damage detail
    local FinalDamage = calcDamage.FinalDamage

    -- local SkillAdditionalDamge = Common.SkillAdditionalDamge
    local Physical = calcDamage.Physical
    local Fixed = 0
    local Elemental = calcDamage.Element
    -- TODO: Missing Parry/Block?
    local Ride = calcDamage.Ride
    local Stun = calcDamage.Stun
    -- bad conditions/debuffs
    local Blast = calcDamage.Blast
    local Paralyse = calcDamage.Paralyse
    local Poison = calcDamage.Poison
    local Sleep = calcDamage.Sleep
    local Stamina = calcDamage.Stamina

    local DebugMode = (mod.Config.Debug or mod.Config.Verbose) and FinalDamage > 0

    if DebugMode then
        local Common = calcDamage.Common
        local AttackerKey = Common.Attacker
        local Attacker = GetAttackerFromKey(AttackerKey)
        local HunterName = GetHunterName(Attacker)
        
        local Msg = string.format("%s: ", HunterName)
        if FinalDamage > 0 then
            Msg = Msg .. Core.FloatFixed1(FinalDamage) .. "(Final)="
        end
        if Physical > 0 then
            Msg = Msg .. Core.FloatFixed1(Physical) .. "(P)"
        end
        if Elemental > 0 then
            Msg = Msg .. "+" .. Core.FloatFixed1(Elemental) .. "(E)"
        end
        -- Msg = Msg .. string.format(", ScarCate: %d, PartCate: %d", Common.ScarDamageCategory, Common.PartsCategory)
        local PartIndex = Common.PartsIndex or 0
        if PartIndex > 0 then
            Msg = Msg .. string.format(", PartIndex [%d]", PartIndex)
        end
        local ScarIndex = Common.ScarIndex or 0
        if ScarIndex > 0 then
            Msg = Msg .. string.format(", ScarIndex [%d]", ScarIndex)
        end
        mod.verbose(Msg)
    end

    if DebugMode then
        local Msg = ""
        local Meat = damageRate.Meat or 1
        local MeatElem = damageRate.MeatElem or 1
        local Angry = damageRate.Angry or 1
        local Difficulity = damageRate.Difficulity or 1
        if not (Meat == 1 and MeatElem == 1 and Angry == 1 and Difficulity == 1) then
            Msg = Msg .. string.format("Meat %0.3f/%0.3f +%0.3f +%0.3f", Meat, MeatElem, Angry, Difficulity)
        end

        local Kireaji = damageRate.Kireaji or 1
        local KireajiElem = damageRate.KireajiElem or 1
        local KireajiStun = damageRate.KireajiStun or 1
        if not (Kireaji == 1 and KireajiElem == 1 and KireajiStun == 1) then
            Msg = Msg .. string.format(", Kireaji %0.3f +%0.3f +%0.3f", Kireaji, KireajiElem, KireajiStun)
        end

        local Hide = damageRate.Hide or 1
        local Sleep = damageRate.Sleep or 1
        local Stun = damageRate.Stun or 1
        local Ride = damageRate.Ride or 1
        if not (Hide == 1 and Sleep == 1 and Stun == 0 and Ride == 1) then
            Msg = Msg .. string.format(", Hide %0.3f, Sleep %0.3f, Stun %0.3f, Ride %0.3f", Hide, Sleep, Stun, Ride)
        end
        if Msg ~= "" then
            Msg = string.sub(Msg, 1, string.len(Msg)-1)
            mod.verbose(Msg)
        end

        Msg = ""
        local LightPlant = damageRate.LightPlant or 1
        local PartsBreak = damageRate.PartsBreak or 1

        local PorterRidingShell = damageRate.PorterRidingShell or 1
        local RidingOther = damageRate.RidingOther or 1
        if not (LightPlant == 0 and PartsBreak == 1 and PorterRidingShell == 1 and RidingOther == 1) then
            Msg = Msg .. string.format(", Other %0.3f +%0.3f +%0.3f +%0.3f", LightPlant, PartsBreak, PorterRidingShell, RidingOther)
        end

        local ScarVital = damageRate.ScarVital or 1
        local TearScarDamage = damageRate.TearScarDamage or 1
        local RawScarDamage = damageRate.RawScarDamage or 1
        local OldScarDamage = damageRate.OldScarDamage or 1
        if not (ScarVital == 1 and TearScarDamage == 1 and RawScarDamage == 1 and OldScarDamage == 1) then
            Msg = Msg .. string.format(", Scar %0.3f +%0.3f +%0.3f +%0.3f", ScarVital, TearScarDamage, RawScarDamage, OldScarDamage)
        end

        local ForAnimal = damageRate.ForAnimal or 1
        local FromEm = damageRate.FromEm or 1
        local FromEmPost = damageRate.FromEmPost or 1
        if not (ForAnimal == 1 and FromEm == 1 and FromEmPost == 1) then
            Msg = Msg .. string.format(", From %0.3f +%0.3f +%0.3f", ForAnimal, FromEm, FromEmPost)
        end
        if Msg ~= "" then
            Msg = string.sub(Msg, 1, string.len(Msg)-1)
            mod.verbose(Msg)
        end
    end
end

return _M
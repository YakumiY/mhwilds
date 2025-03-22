
local function GetHunterCharacterFromObject(attackOwner)
    local hunter = attackOwner:getComponent(Core.Typeof("app.HunterCharacter"))
    if hunter ~= nil then
        return hunter
    end
    -- Owner 可能是app.Weapon
    local weapon = attackOwner:getComponent(Core.Typeof("app.Weapon"))
    if weapon ~= nil then
        return weapon:get_Hunter()
    end

    -- 也可能是 shell
    local shell = attackOwner:getComponent(Core.Typeof("app.AppShell"))
    if shell ~= nil then
        local shellOwner = shell:get_ShellOwner()
        if shellOwner == nil then
            return
        end
        hunter = shellOwner:getComponent(Core.Typeof("app.HunterCharacter"))
        if hunter ~= nil then
            return hunter
        end
        return
    end
end

local function GetEnemyCharacterFromObject(damageOwner)
    local enemy = damageOwner:getComponent(Core.Typeof("app.EnemyCharacter"))
    if enemy ~= nil then
        return enemy
    end
end

---@type DamageRecord | { Attacker: Hunter?, Enemy: EnemyContext?, ConditionType: number, ConditionValue: number }
local cacheDamageRecord = {
    Attacker = nil,
    Enemy = nil,
    Total = 0,
    Physical = 0,
    Elemental = 0,

    ConditionType = 0,
    Parry = 0,
    Ride = 0,
    Poison = 0,
    Paralyse = 0,
    Sleep = 0,
    Blast = 0,
    DefenceDown = 0,
    Stun = 0,
    Stamina = 0,
    Stench = 0,
    Freeze = 0,
    Frenzy = 0,

    ConditionValue = 0,
}

local PLAYER_ATK_COND_TYPE_TO_ENEMY_COND_TYPE_MAP = {
    [CONST.AttackConditionType.POISON] = CONST.EnemyConditionType.Poison,
    [CONST.AttackConditionType.PARALYSE] = CONST.EnemyConditionType.Paralyse,
    [CONST.AttackConditionType.SLEEP] = CONST.EnemyConditionType.Sleep,
    [CONST.AttackConditionType.BLAST] = CONST.EnemyConditionType.Blast,
    [CONST.AttackConditionType.STAMINA] = CONST.EnemyConditionType.Stamina,
}

-- Core.HookFunc("app.EnemyCharacter", "evHit_Damage(app.HitInfo)",
Core.DisabledHookFunc("app.Weapon", "evHit_AttackPostProcess(app.HitInfo)",
function (args)
    local hitInfo = sdk.to_managed_object(args[3])
    local damageOwner = hitInfo:get_DamageOwner()
    local attackData = hitInfo:get_AttackData()

    local enemy = GetEnemyCharacterFromObject(damageOwner)
    if enemy == nil then return end

    local enemyContextHolder = enemy:get_field("_Context")
    if enemyContextHolder == nil then
        return nil
    end

    local enemyContext = enemyContextHolder:get_field("_Em")
    if not enemyContext:get_IsBoss() then
        return
    end

    -- log.info("Enemy.Damage")

    local hunter = GetHunterCharacterFromObject(hitInfo:getActualAttackOwner())
    if hunter == nil then return end

    cacheDamageRecord.Enemy = enemyContext
    cacheDamageRecord.Attacker = hunter

    if attackData._ParryDamage then
        cacheDamageRecord.Parry = attackData._ParryDamage
        cacheDamageRecord.Ride = attackData._RideDamage
    end

    cacheDamageRecord.Elemental = attackData._AttrValue

    cacheDamageRecord.ConditionType = attackData._AttackCond

    if cacheDamageRecord.ConditionType > CONST.AttackConditionType.NONE then
        local enemyCondType = PLAYER_ATK_COND_TYPE_TO_ENEMY_COND_TYPE_MAP[cacheDamageRecord.ConditionType]
        if enemyCondType then
            local cond = enemyContext.Conditions._Conditions:get_Item(enemyCondType)
            if cond then
                if not cond:get_IsActive() then
                    cacheDamageRecord.ConditionValue = cond:get_Value()
                    log.info("已有异常累积值：" .. tostring(cacheDamageRecord.ConditionValue))
                end
                log.info("异常类型：" .. tostring(cacheDamageRecord.ConditionType) .. ", " .. tostring(cond:get_type_definition():get_name()) .. CONST.ENEMY_CONDITIONS[cond._ConditionType])
            end
        elseif enemyCondType > 0 then
            log.info("异常类型未知：" .. tostring(cacheDamageRecord.ConditionType))
        end

    end

    -- cacheDamageRecord.DefenceDown = attackData._DefenceDownDamage
    if attackData._StunDamage > 0 then
        local cond = enemyContext.Conditions._Conditions:get_Item(CONST.EnemyConditionType.Stun)
        if cond and not cond:get_IsActive() then
            cacheDamageRecord.Stun = cond:get_Value()
            log.info("击晕属性：" .. tostring(attackData._StunDamage) .. "，当前累积：" .. tostring(cacheDamageRecord.Stun))
        end
    end
    -- cacheDamageRecord.Stench = attackData._StenchDamage
    -- cacheDamageRecord.Freeze = attackData._FreezeDamage
    -- cacheDamageRecord.Frenzy = attackData._FrenzyDamage
end, function (retval)
    if cacheDamageRecord.Attacker and cacheDamageRecord.Enemy then
        local hunter = cacheDamageRecord.Attacker
        local enemyContext = cacheDamageRecord.Enemy
        local enemyCondType = PLAYER_ATK_COND_TYPE_TO_ENEMY_COND_TYPE_MAP[cacheDamageRecord.ConditionType]
        if enemyCondType then
            local cond = enemyContext.Conditions._Conditions:get_Item(enemyCondType)
            if cond and cacheDamageRecord.ConditionValue > 0 then
                local current
                if cond:get_IsActive() then
                    current = cond:get_LimitValue()
                else
                    current = cond:get_Value()
                end
                log.info("函数后异常累积值：" .. tostring(current))

                local diff = current - cacheDamageRecord.ConditionValue
                log.info("异常累积：" .. tostring(diff))
                if diff > 0 then
                    RecordQuestData.Stun = RecordQuestData.Stun + diff
                    RecordDamageDataSummary[hunter].Stun = RecordDamageDataSummary[hunter].Stun + diff

                    if cacheDamageRecord.ConditionType == CONST.AttackConditionType.POISON then
                        RecordQuestData.Poison = RecordQuestData.Poison + diff
                        RecordDamageDataSummary[hunter].Poison = RecordDamageDataSummary[hunter].Poison + diff
                    elseif cacheDamageRecord.ConditionType == CONST.AttackConditionType.PARALYSE then
                        RecordQuestData.Paralyse = RecordQuestData.Paralyse + diff
                        RecordDamageDataSummary[hunter].Paralyse = RecordDamageDataSummary[hunter].Paralyse + diff
                    elseif cacheDamageRecord.ConditionType == CONST.AttackConditionType.SLEEP then
                        RecordQuestData.Sleep = RecordQuestData.Sleep + diff
                        RecordDamageDataSummary[hunter].Sleep = RecordDamageDataSummary[hunter].Sleep + diff
                    elseif cacheDamageRecord.ConditionType == CONST.AttackConditionType.BLAST then
                        RecordQuestData.Blast = RecordQuestData.Blast + diff
                        RecordDamageDataSummary[hunter].Blast = RecordDamageDataSummary[hunter].Blast + diff
                    elseif cacheDamageRecord.ConditionType == CONST.AttackConditionType.STAMINA then
                        RecordQuestData.Stamina = RecordQuestData.Stamina + diff
                        RecordDamageDataSummary[hunter].Stamina = RecordDamageDataSummary[hunter].Stamina + diff
                    end
                end
            end
        else
            log.info("异常类型未知：" .. tostring(cacheDamageRecord.ConditionType))
        end

        if cacheDamageRecord.Stun > 0 then
            local cond = enemyContext.Conditions._Conditions:get_Item(CONST.EnemyConditionType.Stun)
            local diff
            if cond:get_IsActive() then
                diff = cond:get_LimitValue() - cacheDamageRecord.Stun
            else
                diff = cond:get_Value() - cacheDamageRecord.Stun
            end
                log.info("击晕累积：" .. tostring(diff))
            if diff > 0 then
                RecordQuestData.Stun = RecordQuestData.Stun + diff
                RecordDamageDataSummary[hunter].Stun = RecordDamageDataSummary[hunter].Stun + diff
            end
        end
    end

    cacheDamageRecord.Attacker = nil
    cacheDamageRecord.Enemy = nil
    -- log.info("-- Enemy.Damage")
    cacheDamageRecord.Total = 0
    cacheDamageRecord.Physical = 0
    cacheDamageRecord.Elemental = 0
    cacheDamageRecord.ConditionType = 0
    cacheDamageRecord.ConditionValue = 0
    cacheDamageRecord.Parry = 0
    cacheDamageRecord.Ride = 0
    cacheDamageRecord.Poison = 0
    cacheDamageRecord.Paralyse = 0
    cacheDamageRecord.Sleep = 0
    cacheDamageRecord.Blast = 0
    cacheDamageRecord.DefenceDown = 0
    cacheDamageRecord.Stun = 0
    cacheDamageRecord.Stamina = 0
    cacheDamageRecord.Stench = 0
    cacheDamageRecord.Freeze = 0
    cacheDamageRecord.Frenzy = 0
    return retval
end)

-- Core.HookFunc("app.HunterCharacter", "evHit_AttackPreProcess(app.HitInfo)", function (args)
--     log.info("2.1 Hunter.evHit_AttackPreProcess")
-- end, function (retval)
--     log.info("-- 2.1 Hunter.evHit_AttackPreProcess")
--     return retval
-- end)

-- Core.HookFunc("app.HunterCharacter", "evHit_AttackPostProcess(app.HitInfo)", function (args)
--     log.info("4.2 Hunter.evHit_AttackPostProcess")
-- end, function (retval)
--     log.info("-- 4.2 Hunter.evHit_AttackPostProcess")
--     return retval
-- end)

-- Core.HookFunc("app.EnemyCharacter", "evHit_DamagePreProcess(app.HitInfo)", function (args)
--     log.info("1 Enemy.PreProcess")
-- end, function (retval)
--     log.info("-- 1 Enemy.PreProcess")
--     return retval
-- end)

-- Core.HookFunc("app.EnemyCharacter", "evHit_Damage(app.HitInfo)", function (args)
--     log.info("3 Enemy.evHit_Damage")
-- end, function (retval)
--     log.info("-- 3 Enemy.evHit_Damage")
--     return retval
-- end)

-- Core.HookFunc("app.Weapon", "doHit_AttackPreProcess(app.HitInfo)(app.HitInfo)", function (args)
--     log.info("Weapon.doHit_AttackPre")
-- end, function (retval)
--     log.info("-- Weapon.doHit_AttackPreProcess")
--     return retval
-- end)

-- Core.HookFunc("app.Weapon", "evHit_AttackPostProcess(app.HitInfo)", function (args)
--     log.info("4 Weapon.evHit_AttackPostProcess")
-- end, function (retval)
--     log.info("-- 4 Weapon.evHit_AttackPostProcess")
--     return retval
-- end)

-- Core.HookFunc("app.Weapon", "doHit_AttackPostProcess(app.HitInfo)", function (args)
--     log.info("4.1 Weapon.doHit_AttackPost")
-- end, function (retval)
--     log.info("-- 4.1 Weapon.doHit_AttackPostProcess")
--     return retval
-- end)

-- Core.HookFunc("app.Weapon", "evHit_AttackPreProcess(app.HitInfo)", function (args)
--     log.info("2 Weapon.evHit_AttackPreProcess")
-- end, function (retval)
--     log.info("-- 2 Weapon.evHit_AttackPreProcess")
--     return retval
-- end)

-- Core.HookFunc("app.cEnemyStockDamage", "preStockDamage(app.HitInfo)", function (args)
--     log.info("1.1 cEnemyStockDamage.preStockDamage")
-- end, function (retval)
--     log.info("-- 1.1 cEnemyStockDamage.preStockDamage")
--     return retval
-- end)

-- Core.HookFunc("app.cEnemyStockDamage", "stockDamageDetail(app.HitInfo)", function (args)
--     log.info("3.1 cEnemyStockDamage.stockDamageDetail")
-- end, function (retval)
--     log.info("-- 3.1 cEnemyStockDamage.stockDamageDetail")
--     return retval
-- end)

-- 1 Enemy.PreProcess
-- 2 cEnemyStockDamage.preStockDamage
-- -- 2 cEnemyStockDamage.preStockDamage
-- -- 1 Enemy.PreProcess
-- 1 Weapon.AttackPre
-- 2 Hunter.PreAttack
-- -- 2 Hunter.PreAttack
-- -- 1 Weapon.evHit_AttackPreProcess
-- 1 Enemy.Damage
-- 2 cEnemyStockDamage.stockDamageDetail
-- 3 cEnemyStockDamage.preStockDamage
-- -- 3 cEnemyStockDamage.preStockDamage
-- -- 2 cEnemyStockDamage.stockDamageDetail
-- -- 1 Enemy.Damage
-- 1 Weapon.AttackPost
-- 2 Weapon.doHit_AttackPost
-- -- 2 Weapon.doHit_AttackPostProcess
-- 3 Hunter.PostAttack
-- -- 3 Hunter.PostAttack
-- -- 1 Weapon.evHit_AttackPostProcess

-- 最新版
-- 1 Enemy.PreProcess
-- 1.1 cEnemyStockDamage.preStockDamage
-- -- 1.1 cEnemyStockDamage.preStockDamage
-- -- 1 Enemy.PreProcess
-- 2 Weapon.evHit_AttackPreProcess
-- 2.1 Hunter.evHit_AttackPreProcess
-- -- 2.1 Hunter.evHit_AttackPreProcess
-- -- 2 Weapon.evHit_AttackPreProcess
-- 3 Enemy.evHit_Damage
-- 3.1 cEnemyStockDamage.stockDamageDetail
-- -- 3.1 cEnemyStockDamage.stockDamageDetail
-- -- 3 Enemy.evHit_Damage
-- 4 Weapon.evHit_AttackPostProcess
-- 4.1 Weapon.doHit_AttackPost
-- -- 4.1 Weapon.doHit_AttackPostProcess
-- 4.2 Hunter.evHit_AttackPostProcess
-- -- 4.2 Hunter.evHit_AttackPostProcess
-- -- 4 Weapon.evHit_AttackPostProcess


mod.HookFunc("app.cEnemyStockDamage", "calcApplyDamage()", function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    local storage = thread.get_hook_storage()
    storage["this"] = this

    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Apply DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    
    if not this then return retval end
    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Post Apply DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)

    return retval
end)


-- 没有调用
mod.HookFunc("app.cEnemyStockDamage", "requestDamageGUI(via.vec3, System.Single, app.GUI020020.State, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>, System.Boolean, app.GUI020020.CRITICAL_STATE)", function (args)
    if not StockScarBreakEnemyCtx or not StockScarBreakAttacker then return end
    Core.SendMessage(string.format("stock req gui: %0.1f", sdk.to_float(args[4])))
end)

-- 没有调用
mod.HookFunc("app.GUIManager", "requestDamage(via.vec3, System.Single, app.GUI020020.State, app.TARGET_ACCESS_KEY.CATEGORY, app.GUI020020.DAMAGE_TYPE, app.GUI020020.CRITICAL_STATE)", function (args)
    if not StockScarBreakEnemyCtx or not StockScarBreakAttacker then return end
    Core.SendMessage(string.format("req gui man: %0.1f", sdk.to_float(args[4])))
end)


-- 太杂了
mod.HookFunc("app.cEnemyStockDamage.cScarDamageInfo", "setParam(app.user_data.EmParamParts.SCAR_DAMAGE_CATEGORY, System.Nullable`1<System.Int32>, System.UInt32, via.vec3, app.TARGET_ACCESS_KEY, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Boolean, System.Single, System.Nullable`1<System.Single>)", function (args)
    local dmg = sdk.to_float(args[14])

    local hasValue = sdk.get_native_field(args[7], Core.Typedef("System.Nullable`1<System.Single>)"), "_HasValue")
    if hasValue then
        local dmg2 = sdk.get_native_field(args[7], Core.Typedef("System.Nullable`1<System.Single>)"), "_Value")
        
        Core.SendMessage(string.format("setParam 2vals: %0.1f - %0.1f ",dmg, dmg2))
    else
        Core.SendMessage(string.format("setParam 1vals: %0.1f",dmg))
    end

end)

-- ScarDamage 就是字面意思的对伤口的伤害。所以它在 set External param 时是直接设置满血，而不是具体的爆炸伤害。
-- 因为具体的爆炸伤害是 stock damage 的 External Damage
mod.HookFunc("app.cEnemyStockDamage.cScarDamageInfo", "setExternalParam(System.Single, System.Boolean, System.Boolean, app.TARGET_ACCESS_KEY, System.Boolean)", function (args)
    Core.SendMessage("setExternalParam")
    if not StockScarBreakEnemyCtx or not StockScarBreakAttacker then return end

    local attacker = StockScarBreakAttacker
    local enemyCtx = StockScarBreakEnemyCtx
    StockScarBreakEnemyCtx = nil
    StockScarBreakAttacker = nil

    Core.SendMessage("setExternalParam2")
    local dmg = sdk.to_float(args[3])
    local category = sdk.get_native_field(args[6], TargetAccessKeyType, "Category")
    local isPlayer = category == 0 or category == 5 -- 0 player 5 NPC
    local index = sdk.get_native_field(args[6], TargetAccessKeyType, "UniqueIndex")

    -- 这个返回 nil，为什么啊？
    -- local targetAccessKey = Core.NativeCtor("app.TARGET_ACCESS_KEY", ".ctor(app.TARGET_ACCESS_KEY.CATEGORY, System.Int32)", category, index)

    -- local attacker = GetAttackerFromKey(targetAccessKey)
    -- if attacker == nil then
    --     Core.SendMessage("Cate: " .. tostring(category) .. " " .. tostring(index))
    --     return
    -- end

    local this = sdk.to_managed_object(args[2])
    if not this then return end
    local storage = thread.get_hook_storage()
    storage["this"] = this

    Core.SendMessage("cScarDamageInfo: " .. tostring(dmg))
    RecordFixedDamage(enemyCtx, dmg, attacker, isPlayer)
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    if not this then return retval end
    Core.SendMessage(string.format("POST: %0.1f %0.1f %0.1f", this.Damage, this.ExternalDamage, this.BlastDamage))
end)


-- 这个 不能说没用吧，但是有点难用可能，调试用用差不多了
mod.HookFunc("app.cEnemyStockDamage", "calcApplyDamage()", function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    local storage = thread.get_hook_storage()
    storage["this"] = this

    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Apply DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)
    local exDmg = this:get_field("<ExternalDamage>k__BackingField")
    if exDmg > 0 then
        Core.SendMessage(string.format("Apply Ex DMG: %0.1f", exDmg))
    end
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    
    if not this then return retval end
    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Post Apply DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)
    local exDmg = this:get_field("<ExternalDamage>k__BackingField")
    if exDmg > 0 then
        Core.SendMessage(string.format("Post Apply Ex DMG: %0.1f", exDmg))
    end

    return retval
end)


-- 这个是真的在用的，不过包含了调试信息

mod.HookFunc("app.cEnemyStockDamage", "stockExternalDamageScar(System.Int32, System.Single, System.Boolean, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>, System.Boolean)", function (args)
    -- 参数值：
    -- System.Int32, System.Single, System.Boolean, System.Boolean, System.Nullable`1<app.TARGET_ACCESS_KEY>, System.Boolean
    -- 0             100(伤口生命值)    false           true            ??                                         true

    local this = sdk.to_managed_object(args[2])
    if not this then return end
    local storage = thread.get_hook_storage()
    storage["this"] = this
    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Scar DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)
    local exDmg = this:get_field("<ExternalDamage>k__BackingField")
    if exDmg > 0 then
        Core.SendMessage(string.format("Scar Ex DMG: %0.1f", exDmg))
        -- 虽然没人知道为什么，但是在 PreHook 里已经有了 ExternalDamage
        -- 可能是 set_ExternalDamage(System.Single)
    end

    local enemyCtx = this:get_Context():get_Em()
    local isBoss = enemyCtx:get_IsBoss()
    if not isBoss then return end

    StockScarBreakEnemyCtx = enemyCtx

    local hasValue = sdk.get_native_field(args[7], NullableTargetAccessKeyType, "_HasValue")
    if hasValue then
        local targetAccessKey = sdk.get_native_field(args[7], NullableTargetAccessKeyType, "_Value")
        
        local isPlayer = GetIsPlayerFromKey(targetAccessKey)
        Core.SendMessage("stockCate: " .. tostring(targetAccessKey.Category) .. " " .. tostring(targetAccessKey.UniqueIndex))
        StockScarBreakAttacker = GetAttackerFromKey(targetAccessKey)
        if StockScarBreakAttacker == nil then
            Core.SendMessage("attacker nil")
            return
        end
        local exDmg = this:get_field("<ExternalDamage>k__BackingField")
        if exDmg > 0 then
            Core.SendMessage(string.format("Scar Ex DMG: %0.1f", exDmg))
    
            RecordFixedDamage(enemyCtx, exDmg, StockScarBreakAttacker, isPlayer)
        end
    end
end, function (retval)
    StockScarBreakEnemyCtx = nil
    StockScarBreakAttacker = nil
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    
    if not this then return retval end
    local list = this:get_ScarDamage()
    Core.ForEach(list, function (scarDmgInfo)
        if scarDmgInfo.DamageCategory > 0 and scarDmgInfo.Damage > 0 then
            Core.SendMessage(string.format("[%d] Post Scar DMG: %0.1f/%0.1f/%0.1f", scarDmgInfo.DamageCategory, scarDmgInfo.Damage, scarDmgInfo.ExternalDamage, scarDmgInfo.BlastDamage))
        end
    end)
    local exDmg = this:get_field("<ExternalDamage>k__BackingField")
    if exDmg > 0 then
        Core.SendMessage(string.format("Post Scar Ex DMG: %0.1f", exDmg))
    end
end)

mod.HookFunc("app.cEnemyStockDamage.cWeakPointDamageInfo", "setParam(System.Single, System.Boolean, app.TARGET_ACCESS_KEY)", function (args)
    if not StockWeakPointEnemyCtx or not StockWeakPointAttacker then return end

    local attacker = StockWeakPointAttacker
    local enemyCtx = StockWeakPointEnemyCtx
    StockWeakPointEnemyCtx = nil
    StockWeakPointAttacker = nil

    local dmg = sdk.to_float(args[3])
    local category = sdk.get_native_field(args[5], TargetAccessKeyType, "Category")
    local isPlayer = category == 0 or category == 5 -- 0 player 5 NPC
    local index = sdk.get_native_field(args[5], TargetAccessKeyType, "UniqueIndex")

    Core.SendMessage("cWeakPointDamageInfo: " .. tostring(dmg))
    RecordFixedDamage(enemyCtx, dmg, attacker, isPlayer)
end)

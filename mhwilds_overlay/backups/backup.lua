
mod.OnDebugFrame(function()
    imgui.push_font(Core.LoadImguiCJKFont())
    local otomo = sdk.get_managed_singleton("app.OtomoManager"):getMasterOtomoInfo():get_Character()
    local otomoCtx = otomo:get_OtomoContext() -- cOtomoContext
    -- local otomoNetInfo = otomoCtx:get_NetMemberInfo() -- app.cOtomoNetMemberInfo
    -- local questIndex = otomoNetInfo._StableQuestIndex
    -- local uniqueID = otomoNetInfo._UniqueID
    -- imgui.text(tostring(questIndex)) -- -1 ...
    -- imgui.text(tostring(uniqueID))
    -- imgui.text(tostring(Core.GetLocalizedText(uniqueID)))

    local hunter = otomo:get_OwnerHunterCharacter()
    local hunterExtendPlayer = hunter:get_HunterExtend() -- app.HunterCharacter.cHunterExtendBase
    local questIndex = hunterExtendPlayer:get_StableQuestMemberIndex()
    imgui.text(tostring(questIndex))

    local mgr = Core.GetSingleton("app.NetworkManager")
    local netMgr = mgr:get_UserInfoManager()
    local netUserInfoList = netMgr:getUserInfoList(2) -- app.Net_UserInfoList, app.net_session_manager.SESSION_TYPE
    local memberNum = netUserInfoList:get_MemberNum()
    imgui.text(tostring(memberNum))

    if questIndex == 0 and memberNum == 0 then
        imgui.text(tostring(mgr._OtomoName))
        imgui.text(tostring(mgr:SelfOtomoName()))
    else
        local netUserInfo = netUserInfoList:call("getInfo(System.Int32)", questIndex) -- app.Net_UserInfo
        local otomoName = netUserInfo:get_OtomoName()
        imgui.text(tostring(otomoName))
    end

    local save = Core.GetSaveDataManager():getCurrentUserSaveData()
    local basicParam = save._BasicData -- app.savedata.cBasicParam
    local hp = basicParam:getHunterPoint()
    imgui.text("HP: " .. tostring(hp))
    local hr = basicParam:getHunterRank(hp)
    imgui.text("HR: " .. tostring(hr))
    hr = basicParam:getHunterRank(40000)
    imgui.text("HR: " .. tostring(hr))
    imgui.pop_font()
end)


local function ___LogCalcDamage_NoUsed(calcDamage)
    if not calcDamage then return end
    local Msg = ""

    -- no need
    local PhysicalParts = calcDamage.PhysicalParts or 0
    local PhysicalScar = calcDamage.PhysicalScar or 0
    local ElementParts = calcDamage.ElementParts or 0
    local ElementScar = calcDamage.ElementScar or 0
    local BlastEm = calcDamage.BlastEm or 0
    local Capture = calcDamage.Capture or 0
    local EmLead = calcDamage.EmLead or 0
    local Koyashi = calcDamage.Koyashi or 0
    local ParalyseEm = calcDamage.ParalyseEm or 0
    local PoisonEm = calcDamage.PoisonEm or 0
    local SleepEm = calcDamage.SleepEm or 0
    if PhysicalParts > 0 then
        Msg = Msg .. Core.FloatFixed1(PhysicalParts) .. "(PhysicalParts)\n"
    end
    if PhysicalScar > 0 then
        Msg = Msg .. Core.FloatFixed1(PhysicalScar) .. "(PhysicalScar)\n"
    end
    if ElementParts > 0 then
        Msg = Msg .. Core.FloatFixed1(ElementParts) .. "(ElementParts)\n"
    end
    if ElementScar > 0 then
        Msg = Msg .. Core.FloatFixed1(ElementScar) .. "(ElementScar)\n"
    end
    if BlastEm > 0 then
        Msg = Msg .. Core.FloatFixed1(BlastEm) .. "(BlastEm)\n"
    end
    if EmLead > 0 then
        Msg = Msg .. Core.FloatFixed1(EmLead) .. "(EmLead)\n"
    end
    if ParalyseEm > 0 then
        Msg = Msg .. Core.FloatFixed1(ParalyseEm) .. "(ParalyseEm)\n"
    end
    if PoisonEm > 0 then
        Msg = Msg .. Core.FloatFixed1(PoisonEm) .. "(PoisonEm)\n"
    end
    if SleepEm > 0 then
        Msg = Msg .. Core.FloatFixed1(SleepEm) .. "(SleepEm)\n"
    end
    if Capture > 0 then
        Msg = Msg .. Core.FloatFixed1(Capture) .. "(Capture)\n"
    end
    if Koyashi > 0 then
        Msg = Msg .. Core.FloatFixed1(Koyashi) .. "(Koyashi)\n"
    end

    if false then
        local Msg = ""
        
        local LightPlant = calcDamage.LightPlant or 0
        local SkillStabbing = calcDamage.SkillStabbing or 0
        local SkillRyuki = calcDamage.SkillRyuki or 0
        local PreScarIndex = calcDamage.PreScarIndex or 0
        local RateHitResult = calcDamage.RateHitResult or 0
        local WeakAttrBoost = calcDamage.WeakAttrBoost or 0
        local WeakAttrSlinger = calcDamage.WeakAttrSlinger or 0
        local SkillRyuki = calcDamage.SkillRyuki or 0
        if LightPlant > 0 then
            Msg = Msg .. Core.FloatFixed1(LightPlant) .. "(LightPlant)\n"
        end
        Core.ForEach(SkillStabbing, function (Stab, i)
            if Stab > 0 then
                Msg = Msg .. Core.FloatFixed1(Stab) .. string.format("(Stab %d)\n", i)
            end
        end)
        if SkillRyuki > 0 then
            Msg = Msg .. Core.FloatFixed1(SkillRyuki) .. "(SkillRyuki)\n"
        end
        if SkillRyuki > 0 then
            Msg = Msg .. Core.FloatFixed1(SkillRyuki) .. "(SkillRyuki)\n"
        end
        if PreScarIndex > 0 then
            Msg = Msg .. Core.FloatFixed1(PreScarIndex) .. "(PreScarIndex)\n"
        end
        if RateHitResult > 0 then
            Msg = Msg .. Core.FloatFixed1(RateHitResult) .. "(RateHitResult)\n"
        end
        if ScarIndex > 0 then
            Msg = Msg .. Core.FloatFixed1(ScarIndex) .. "(ScarIndex)\n"
        end
        if WeakAttrBoost > 0 then
            Msg = Msg .. Core.FloatFixed1(WeakAttrBoost) .. "(WeakAttrBoost)\n"
        end
        if WeakAttrSlinger > 0 then
            Msg = Msg .. Core.FloatFixed1(WeakAttrSlinger) .. "(WeakAttrSlinger)\n"
        end
        local MultiPartsPhysical = calcDamage.MultiPartsPhysical
        Core.ForEach(MultiPartsPhysical, function (Phys, i)
            if Phys > 0 then
                Msg = Msg .. Core.FloatFixed1(Phys) .. string.format("(Phys %d)\n", i)
            end
        end)
        local MultiPartsElement = calcDamage.MultiPartsElement
        Core.ForEach(MultiPartsElement, function (Ele, i)
            if Ele > 0 then
                Msg = Msg .. Core.FloatFixed1(Ele) .. string.format("(Ele %d)\n", i)
            end
        end)

        local common = calcDamage.Common
        local Heal = common.Heal or 0
        local RidingScarDamage = common.RidingScarDamage or 0
        local RidingSuccessDamage = common.RidingSuccessDamage or 0
        local SkillAdditionalDamge = common.SkillAdditionalDamge or 0
        if Heal > 0 then
            Msg = Msg .. Core.FloatFixed1(Heal) .. "(Heal)\n"
        end
        if RidingScarDamage > 0 then
            Msg = Msg .. Core.FloatFixed1(RidingScarDamage) .. "(RidingScarDamage)\n"
        end
        if RidingSuccessDamage > 0 then
            Msg = Msg .. Core.FloatFixed1(RidingSuccessDamage) .. "(RidingSuccessDamage)\n"
        end
        if SkillAdditionalDamge > 0 then
            Msg = Msg .. Core.FloatFixed1(SkillAdditionalDamge) .. "(SkillAdditionalDamge)\n"
        end

        Core.SendMessage(Msg)
    end

    -- unknown
    local LightPlant = calcDamage.LightPlant or 0
    local PreScarIndex = calcDamage.PreScarIndex or 0
    local RateHitResult = calcDamage.RateHitResult or 0
    local ScarIndex = calcDamage.ScarIndex or 0
    local WeakAttrBoost = calcDamage.WeakAttrBoost or 0
    local WeakAttrSlinger = calcDamage.WeakAttrSlinger or 0
    local SkillRyuki = calcDamage.SkillRyuki or 0
    if LightPlant > 0 then
        Msg = Msg .. Core.FloatFixed1(LightPlant) .. "(LightPlant)\n"
    end
    if SkillRyuki > 0 then
        Msg = Msg .. Core.FloatFixed1(SkillRyuki) .. "(SkillRyuki)\n"
    end
    if PreScarIndex > 0 then
        Msg = Msg .. Core.FloatFixed1(PreScarIndex) .. "(PreScarIndex)\n"
    end
    if RateHitResult > 0 then
        Msg = Msg .. Core.FloatFixed1(RateHitResult) .. "(RateHitResult)\n"
    end
    if ScarIndex > 0 then
        Msg = Msg .. Core.FloatFixed1(ScarIndex) .. "(ScarIndex)\n"
    end
    if WeakAttrBoost > 0 then
        Msg = Msg .. Core.FloatFixed1(WeakAttrBoost) .. "(WeakAttrBoost)\n"
    end
    if WeakAttrSlinger     > 0 then
        Msg = Msg .. Core.FloatFixed1(WeakAttrSlinger) .. "(WeakAttrSlinger)\n"
    end


    
    -- record
    local FinalDamage = calcDamage.FinalDamage or 0
    local Physical = calcDamage.Physical or 0
    local Element = calcDamage.Element or 0
    -- TODO: Missing Parry?
    local Ride = calcDamage.Ride or 0
    local Stun = calcDamage.Stun or 0
    -- bad conditions/debuffs
    local Blast = calcDamage.Blast or 0
    local Paralyse = calcDamage.Paralyse or 0
    local Poison = calcDamage.Poison or 0
    local Sleep = calcDamage.Sleep or 0
    local Stamina = calcDamage.Stamina or 0

    local Msg = ""
    if FinalDamage > 0 then
        Msg = Msg .. Core.FloatFixed1(FinalDamage) .. "="
    end
    if Physical > 0 then
        Msg = Msg .. Core.FloatFixed1(Physical) .. "(P)\n"
    end
    if Element > 0 then
        Msg = Msg .. "+" .. Core.FloatFixed1(Element) .. "(E)\n"
    end

    -- special
    if Ride > 0 then
        Msg = Msg .. Core.FloatFixed1(Ride) .. "(Ride)\n"
    end
    if Stun > 0 then
        Msg = Msg .. Core.FloatFixed1(Stun) .. "(Stun)\n"
    end

    -- debuffs
    if Blast > 0 then
        Msg = Msg .. Core.FloatFixed1(Blast) .. "(Blast)\n"
    end
    if Paralyse > 0 then
        Msg = Msg .. Core.FloatFixed1(Paralyse) .. "(Paralyse)\n"
    end
    if Poison > 0 then
        Msg = Msg .. Core.FloatFixed1(Poison) .. "(Poison)\n"
    end
    if Sleep > 0 then
        Msg = Msg .. Core.FloatFixed1(Sleep) .. "(Sleep)\n"
    end
    if Stamina > 0 then
        Msg = Msg .. Core.FloatFixed1(Stamina) .. "(Stamina)"
    end

    if Msg ~= "" then
        Core.SendMessage(Msg)
    else
        Msg = calcDamage:get_type_definition():get_full_name()
        Core.SendMessage("Nil calc damage: " .. Msg)        
    end
end

-- Core.HookFunc("app.cEmModuleRide", "subSuccessVital(System.Single)",
-- function (args)
--     local dmg = sdk.to_float(args[3])
--     if dmg <= 0 then
--         return
--     end
--     Core.SendMessage("Ride DMG: " .. string.format("%0.1f", dmg))
-- end)
-- Core.HookFunc("app.cEmModuleRide.mcUpdater", "evDamage(app.EnemyDef.Damage.cApplyEventParam)",
-- function (args)
--     local param = sdk.to_managed_object(args[3])
--     if param.Damage <= 0 then
--         return
--     end
--     Core.SendMessage("Ride DMG: " .. string.format("%0.1f, %s", param.Damage, param:get_type_definition():get_name()))
-- end)
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
local DpsChartData = require("mhwilds_overlay.dps_chart.data")
local BossData = require("mhwilds_overlay.boss.data")
local StatusData = require("mhwilds_overlay.status.data")

local CollectorDamage = require("mhwilds_overlay.collector_damage")
local CollectorPlayer = require("mhwilds_overlay.collector_player")

local MAX_UPDATES_PER_TICK = 4
local function NewTrackData()
    return {
        TickIndex = 0,
        KnownContexts = {},
        KnownCount = 0,

        UpdatedCount = 0, -- 当前帧已更新的数量
        UpdatesPerTick = MAX_UPDATES_PER_TICK,
        UpdatedContexts = {},
    }
end

local TrackData = NewTrackData()

local function UpdateTrackData()
    TrackData.TickIndex = TrackData.TickIndex + 1
    TrackData.UpdatedCount = 0

    if TrackData.TickIndex > TrackData.KnownCount*TrackData.UpdatesPerTick or TrackData.UpdatedCount > TrackData.KnownCount then
        TrackData = NewTrackData()
    end
end

local function ClearData()
    TrackData = NewTrackData()
end

mod.OnDebugFrame(function ()
    -- imgui.push_font(Core.LoadImguiCJKFont())
    -- for ctx, data in pairs(OverlayData.EnemyInfo) do
    --     local id = ctx:get_EmID()
    --     imgui.text(string.format("%s: %0.1f/%0.1f", Core.GetEnemyName(id), data.HP, data.MaxHP))
    -- end
    -- imgui.pop_font()
    for hunter, data in pairs(OverlayData.HunterInfo) do
        if not hunter.IsLeave and hunter.get_IsCombatBoss then
            imgui.text("Hunter is combat boss: " .. tostring(hunter:get_IsCombatBoss()))
            imgui.text("Hunter is player: " .. tostring(data.IsPlayer))
            imgui.text("Hunter IsCombatBoss: " .. tostring(data.IsCombatBoss))
            imgui.text("Hunter FightingTime: " .. tostring(data.FightingTime))
            imgui.text("Hunter LastCombatBossStartTime: " .. tostring(data.LastCombatBossStartTime))
        end
    end
end)

local DeltaTime = 0.016 -- 时间停止更新时，假设每帧16ms
-- local UpTime = 0
-- mod.OnFrame(function ()
--     imgui.text(string.format("%0.4f", Core.GetDeltaTime()))
--     imgui.text(string.format("%0.4f", DeltaTime))
--     imgui.text(string.format("%0.4f", OverlayData.QuestStats.ElapsedTime))
--     imgui.text(string.format("%0.4f", UpTime))
-- end)
local SIMULATION_TIME_MAX = 60*50
mod.OnUpdateBehavior(function ()
    UpdateTrackData()

    DeltaTime = Core.GetDeltaTime() / 100
    -- UpTime = UpTime + 0.016

    if OverlayData.QuestStats.ElapsedTime == nil then
        OverlayData.QuestStats.ElapsedTime = 0
        OverlayData.QuestStats.LimitTime = -1
    end
    local isPlayingQuest = Core.IsPlayingQuest()
    local isTraningArea = Core.IsInTrainingArea()
    if isTraningArea then
        if #OverlayData.TraningAreaEnemies == 0 then
            OverlayData.InitTraningArea(true)
        end
        OverlayData.QuestStats.ElapsedTime = OverlayData.QuestStats.ElapsedTime + DeltaTime
        if OverlayData.QuestStats.ElapsedTime >= SIMULATION_TIME_MAX then
            OverlayData.QuestStats.ElapsedTime = 0
        end
    elseif Core.IsActiveQuest() then
        if isPlayingQuest then
            OverlayData.QuestStats.ElapsedTime = Core.GetQuestElapsedTime()
            if OverlayData.QuestStats.LimitTime <= 0 then
                OverlayData.QuestStats.LimitTime = Core.GetQuestTimeLimit()
            end

            for hunter, data in pairs(OverlayData.HunterInfo) do
                if not data or data.IsLeave then
                    goto continue
                end

                if data.IsPlayer then
                    if not data.Name or not data.HR then
                        OverlayData.HunterInfo[hunter].Name = OverlayData.GetHunterName(hunter)
                        OverlayData.HunterInfo[hunter].HR = OverlayData.GetHunterHR(hunter)
                    end
                else
                    if not data.Name then
                        OverlayData.HunterInfo[hunter].Name = OverlayData.GetOtomoName(hunter)
                    end
                end

                if data.IsPlayer and OverlayData.HunterDamageRecords[hunter] and hunter.get_IsCombatBoss then
                    local isCombat = false
                    local ok = pcall(function ()
                        isCombat = hunter:get_IsCombatBoss()
                    end)
                    if not ok then
                        isCombat = false
                        data.IsLeave = true
                    end

                    if isCombat and OverlayData.HunterInfo[hunter].LastCombatBossStartTime > 0 then
                        local fightTime = OverlayData.QuestStats.ElapsedTime - OverlayData.HunterInfo[hunter].LastCombatBossStartTime
                        OverlayData.HunterInfo[hunter].FightingTime = OverlayData.HunterInfo[hunter].FightingTime + fightTime
                    end
                    OverlayData.HunterInfo[hunter].LastCombatBossStartTime = OverlayData.QuestStats.ElapsedTime
                    OverlayData.HunterInfo[hunter].IsCombatBoss = isCombat
                end
                if data.IsPlayer then
                    local wpType = OverlayData.HunterInfo[hunter].WeaponType
                    local ok = pcall(function ()
                        wpType = hunter:get_Weapon()._WpType
                    end)
                    if ok then
                        OverlayData.HunterInfo[hunter].WeaponType = wpType
                    else
                        data.IsLeave = true
                    end
                end

                ::continue::
            end
        end
    elseif mod.Config.ClearDataAfterQuestComplete then
        OverlayData.QuestStats.ElapsedTime = 0
        OverlayData.QuestStats.LimitTime = -1
    end
    
    if (OverlayData.QuestStats.LimitTime <= 0) or (OverlayData.QuestStats.ElapsedTime - OverlayData.SimulatedTime < 0.001 and not isPlayingQuest) then
        OverlayData.SimulatedTime = OverlayData.SimulatedTime + DeltaTime
    else
        OverlayData.SimulatedTime = OverlayData.QuestStats.ElapsedTime
    end
end)

local Enemy_GetHealthManager = Core.TypeMethod("app.EnemyCharacter", "get_HealthMgr")

local Enemy_ContextHolder = Core.TypeField("app.EnemyCharacter", "_Context")
local EnemyContextHolder_Context = Core.TypeField("app.cEnemyContextHolder", "_Em")

local HealthManager_GetHealth = Core.TypeMethod("app.cHealthManager", "get_Health")
local HealthManager_GetMaxHealth = Core.TypeMethod("app.cHealthManager", "get_MaxHealth")

---@param character app.EnemyCharacter
local function ShouldUpdate(character)
    if not TrackData.KnownContexts[character] then
        TrackData.KnownContexts[character] = true
        TrackData.KnownCount = TrackData.KnownCount + 1
    end

    if OverlayData.EnemyInfo[character] and OverlayData.EnemyInfo[character].IsTarget then
        return true
    end

    local shouldUpdate = false
    if TrackData.UpdatedCount < TrackData.UpdatesPerTick then
        if TrackData.UpdatedContexts[character] then
           return
        end

        TrackData.UpdatedCount = TrackData.UpdatedCount + 1
        TrackData.UpdatedContexts[character] = true
        shouldUpdate = true
    end

    if not shouldUpdate then
        return
    end
end

---@param this app.EnemyCharacter
local function UpdateEnemyHealth(this, force)
    -- 这个其实不太能提高多少性能，因为实际上 get health 貌似是个消耗很低很低的东西（实测约90次调用不到0.6ms->0.2ms）
    -- 反而导致逻辑变复杂+更新变迟缓许多，除非在增加受伤的钩子，在受伤后强制刷新。
    -- 仔细想想说不定不错？不是一直update，而是在受伤之后才 update
    -- if not force and not ShouldUpdate(this) then
    --     return
    -- end

    local ctxHolder = Enemy_ContextHolder:get_data(this)
    if ctxHolder == nil then return end

    local ctx = EnemyContextHolder_Context:get_data(ctxHolder)
    if ctx == nil then return end

    OverlayData.InitEnemyCtx(ctx, this)

    local hpMgr = Enemy_GetHealthManager:call(this)
    if hpMgr == nil then return end

    local hp = HealthManager_GetHealth:call(hpMgr)
    local maxHp = HealthManager_GetMaxHealth:call(hpMgr)

    local info = OverlayData.EnemyInfo[ctx]
    if info then
        if info.IsBoss then
            -- mod.verbose(string.format("Update boss hp: %s/%s", tostring(hp), tostring(maxHp)))
        elseif info.IsZako then
            -- mod.verbose(string.format("Update zako hp: %s/%s", tostring(hp), tostring(maxHp)))
        elseif info.IsAnimal then
            -- mod.verbose(string.format("Update animal hp: %s/%s", tostring(hp), tostring(maxHp)))
        end
    end
    OverlayData.UpdateEnemyCtxHealth(ctx, hp, maxHp)
end

-- local function GetShellNameByAppShell(attacker)
--     local setupArgs = shell:get_field("<Setting>k__BackingField")
--     local effectParam = setupArgs._EffectParam
--     local mainParam = setupArgs._MainParam
--     local nameHash = setupArgs._NameHash

--     local shellIndex
--     local paramMatchIndex

--     local ctrl = attacker:get_Weapon()._ShellCreateController
--     local list = ctrl._ShellList._DataList

--     if not shellIndex then
--         Utils.ForEach(list, function (shell, i)
--             local pkg = shell._ShellPackage
--             if nameHash == pkg._ShellNameHash then
--                 shellIndex = i
--                 return Utils.ForEachBreak
--             end

--             local param = pkg._MainParam
--             if pkg._MainParam == mainParam and effectParam == pkg._EffectParam then
--                 paramMatchIndex = i
--                 if colID == pkg._AttackCollisionID then
--                     shellIndex = i
--                     return Utils.ForEachBreak
--                 end
--             end
--             -- Core.SendMessage("[%d]%s: %x vs %x", i, shellNames[i], param:get_address(), argParam:get_address())
--         end)
--     end

--     local wpFunc = WeaponTypeShellIndexFunctions[wpType]
--     if not wpFunc then
--         return nil
--     end
--     if shellIndex then
--         return wpFunc(shellIndex, colID, lang)
--     elseif paramMatchIndex then
--         return wpFunc(paramMatchIndex, colID, lang)
--     end

--     return nil
-- end

-- local function PatchHitInfo(hitInfo)
--     if not hitInfo then
--         return
--     end
--     if OverlayData.IsQuestHost then
--         return
--     end

--     local attackOwner = hitInfo:get_AttackOwner()
--     local actualAttackOwner = hitInfo:getActualAttackOwner()
--     local hunter = actualAttackOwner:getComponent(Core.Typeof("app.HunterCharacter"))
--     if not hunter then
--         return
--     end
--     mod.verbose("Patching hit info")

--     local attackName = attackOwner:get_Name()
--     local actualAttackName = actualAttackOwner:get_Name()

--     local baseActionController = hunter:get_BaseActionController()
--     local action = baseActionController:get_CurrentAction()
--     local actionClass = action:get_type_definition():get_name()

--     local attackData = hitInfo:get_AttackData() -- get_AttackData() -- cAttackParamBase （实际上是 cAttackParamPl）
--     local Atk = attackData:get_field("_Attack")
--     if Atk <= 1.0 then
--         mod.verbose("Patch to 100")
--     end
--     -- if Core.StringContains(attackName, "Shell") then
--     --     -- attackData._Attack = 100
--     --     mod.verbose("Patch to 100")
--     --     hitInfo:set_field("<AttackData>k__BackingField", attackData)
--     -- end
-- end

-- evDamage_Health(System.Single) 只在单人有用
mod.HookFunc("app.EnemyCharacter", "evHit_Damage(app.HitInfo)",
function (args)
    -- mod.verbose("Eval Damage hook")
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local storage = thread.get_hook_storage()
    storage["this"] = this
    storage["args"] = args

    -- PatchHitInfo(Core.Cast(args[3]))
end, function (retval)
    local storage = thread.get_hook_storage()
    local this = storage["this"]
    storage["this"] = nil
    if not this then
        return retval
    end

    UpdateEnemyHealth(this, true)
end)

-- mod.OnPreUpdateBehavior(function ()
--     mod.InitCost("EnemyUpdate")
--     mod.InitCost("EnemyUpdateHealth")
-- end)

mod.HookFunc("app.EnemyCharacter", "doUpdateEnd()",
function(args)
    -- 理论上使用 RequestCtx 可能更好，因为即使是 to_managed_object 也会在巨大的调用下消耗大约0.2ms

    -- 不使用 Core.ToEnemyCharacter，因为在这个调用量下这甚至可能导致~0.05ms的性能损失？
    local this = sdk.to_managed_object(args[2])
    if this == nil then return end
    local storage = Core.HookStorage()
    storage["this"] = this
end, function(retval)
    local storage = Core.HookStorage()
    local this= storage["this"]
    if not this then
        return
    end

    if not OverlayData.IsQuestHost and ShouldUpdate(this) then
        -- mod.verbose("ShouldUpdate " .. tostring(this))
        UpdateEnemyHealth(this, true)
        -- local ctx = OverlayData.GetEnemyContext(this)
        -- if BossData.ComplexDataCollectionTargets[ctx] then
        --     mod.verbose("  Update " .. tostring(ctx))
        --     BossData.UpdateEnemyCtx(OverlayData.EnemyCharacterData[this].Ctx)
        -- end
    end

    -- mod.RecordCost("EnemyUpdate", function ()
        -- OverlayData.RequestUpdateEnemyHealth = true
        if OverlayData.RequestUpdateEnemyHealth or OverlayData.EnemyCharacterData[this] == nil then
            -- mod.verbose("UpdateEnemyCharacter " .. tostring(this))
            UpdateEnemyHealth(this, true)
            OverlayData.RequestUpdateEnemyHealth = false
        end

        if OverlayData.IsQuestHost then
            local ctx = OverlayData.EnemyCharacterData[this].Ctx
            if OverlayData.EnemyInfo[ctx] and OverlayData.EnemyInfo[ctx].HP > 0 then
                BossData.UpdateEnemyCtx(OverlayData.EnemyCharacterData[this].Ctx)
            end
        end
    -- end, true)
    -- mod.RecordCost("EnemyUpdateHealth", function ()
    --     UpdateEnemyHealth(this)
    -- end, true)
end)

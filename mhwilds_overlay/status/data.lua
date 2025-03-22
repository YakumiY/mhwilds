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

local mod = require("mhwilds_overlay.mod")

local MantleStats = require("mhwilds_overlay.mantle_stats")


local _M = {}

---@class BuffStatus
---@field Activated boolean
---@field Timer number
---@field MaxTimer number
---@field Name string|nil
---@field BuffLevel number

---@class SkillStatus : BuffStatus
---@field Level integer

local function NewBuffStatus(max)
    return {
        Activated = true,
        Timer = 0,
        MaxTimer = max or 0,
        Name = nil,
    }
end

local MusicSkillTypeNames = Core.GetEnumMap("app.Wp05Def.WP05_MUSIC_SKILL_TYPE")
local OtomoSkillTypeNames = Core.GetEnumMap("app.OtomoDef.MUSIC_SKILL_TYPE")
local ASkillTypeNames = Core.GetEnumMap("app.HunterDef.ACTIVE_SKILL")

---@class HunterHealthData
---@field Health number
---@field MaxHealth number
---@field RedHealth number
---@field Heal number

---@class HunterStaminaData
---@field Stamina number
---@field MaxStamina number
---@field StaminaTough number
---@field MaxStaminaTough number
---@field StaminaLimit number
---@field AutoMaxReduceTimer number

---@class InsectStaminaData
---@field Stamina number
---@field MaxStamina number
---@field Ratio number

---@class HunterStatusData
---@field Hunter app.HunterCharacter
---@field WeaponHandling app.cHunterWeaponHandlingBase
---@field WeaponType app.WeaponDef.TYPE
---@field Transform via.Transform
---@field GameObject via.GameObject
---@field Status app.cHunterStatus
---@field Health app.cHunterHealth
---@field Stamina app.cHunterStamina
---@field Pos via.vec3
---@field HealthData HunterHealthData
---@field StaminaData HunterStaminaData
---@field InsectStaminaData InsectStaminaData

---@return HunterStatusData
local function NewHunterData()
    return {
        HealthData = {},
        StaminaData = {},
        InsectStaminaData = {},
    }
end

---@type HunterStatusData
_M.HunterData = NewHunterData()
---@type table<app.HunterDef.Skill, SkillStatus>
_M.SkillData = {}
---@type table<integer, BuffStatus>
_M.MuiscSkillData = {} -- 长度是59，但笛子Enum只有52？
---@type table<integer, BuffStatus>
_M.OtomoSkillData = {}
---@type table<string, BuffStatus>
_M.ItemBuffData = {}
---@type table<integer, BuffStatus>
_M.ASkillData = {}
---@type table<string, BuffStatus>
_M.WeaponBuffData = {}

---@param character app.HunterCharacter
function _M.Init()
    if not  _M.HunterData.Hunter then
        _M.HunterData.Hunter = Core.GetPlayerCharacter()
        _M.HunterData.WeaponHandling = Core.GetPlayerWeaponHandling()
        _M.HunterData.WeaponType = Core.GetPlayerWeaponType()
    end
    if not  _M.HunterData.Hunter then return end

    local hunter = _M.HunterData.Hunter
    if not _M.HunterData.Transform then
        _M.HunterData.GameObject = hunter:get_GameObject()
        _M.HunterData.Transform = _M.HunterData.GameObject:get_Transform()
    end

    if not _M.HunterData.Status then
        _M.HunterData.Status = hunter:get_HunterStatus()
    end
    if not _M.HunterData.Health then
        _M.HunterData.Health = hunter:get_HunterHealth()
    end
    if not _M.HunterData.Stamina then
        _M.HunterData.Stamina = hunter:get_HunterStamina()
    end
end

function _M.ClearData()
    _M.HunterData = NewHunterData()
    _M.SkillData = {}
    _M.MuiscSkillData = {}
    _M.OtomoSkillData = {}
    _M.ItemBuffData = {}
    _M.ASkillData = {}
    _M.WeaponBuffData = {}
end

local Transform_GetPosition = Core.TypeMethod("via.Transform", "get_Position")

---@param Hunter app.HunterCharacter
function _M.UpdateHunter(Hunter)
    if Hunter ~= _M.HunterData.Hunter then
        return
    end
    
    _M.HunterData.WeaponType = Core.GetPlayerWeaponType()
    _M.HunterData.Pos = Transform_GetPosition:call(_M.HunterData.Transform)

    _M.UpdateWeaponHandling(Hunter:get_WeaponHandling())
end

local HealthManager_GetHealth = Core.TypeMethod("app.cHealthManager", "get_Health")
local HealthManager_GetMaxHealth = Core.TypeMethod("app.cHealthManager", "get_MaxHealth")
local HunterHealth_GetRedHealth = Core.TypeMethod("app.cHunterHealth", "get_RedHealth")
local HunterHealth_RequestedTotalHealValue = Core.TypeField("app.cHunterHealth", "_RequestedTotalHealValue")

---@param HunterHealth app.cHunterHealth
function _M.UpdateHunterHealth(HunterHealth)
    if HunterHealth ~= _M.HunterData.Health then
        return
    end

    local hpMgr = HunterHealth:get_HealthMgr()
    if not hpMgr then return end

    local health = _M.HunterData.HealthData
    health.Health = HealthManager_GetHealth:call(hpMgr) or 0
    health.MaxHealth = HealthManager_GetMaxHealth:call(hpMgr) or 1
    health.RedHealth = HunterHealth_GetRedHealth:call(HunterHealth) or 0
    health.Heal = HunterHealth_RequestedTotalHealValue:get_data(HunterHealth) or 0

    _M.HunterData.HealthData = health
end

local HunterStamina_GetStamina = Core.TypeMethod("app.cHunterStamina", "get_Stamina")
local HunterStamina_GetMaxStamina = Core.TypeMethod("app.cHunterStamina", "get_MaxStamina")
local HunterStamina_GetStaminaTough = Core.TypeMethod("app.cHunterStamina", "get_StaminaTough")
local HunterStamina_GetMaxStaminaTough = Core.TypeMethod("app.cHunterStamina", "get_MaxStaminaTough")
local HunterStamina_GetStaminaLimit = Core.TypeMethod("app.cHunterStamina", "get_StaminaLimit")
local HunterStamina_GetAutoMaxReduceTimer = Core.TypeMethod("app.cHunterStamina", "get_AutoMaxReduceTimer")

---@param HunterStamina app.cHunterStamina
function _M.UpdateHunterStamina(HunterStamina)
    if HunterStamina ~= _M.HunterData.Stamina then
        return
    end

    local stamina = _M.HunterData.StaminaData
    stamina.Stamina = HunterStamina_GetStamina:call(HunterStamina) or 0
    stamina.MaxStamina = HunterStamina_GetMaxStamina:call(HunterStamina) or 1
    stamina.StaminaTough = HunterStamina_GetStaminaTough:call(HunterStamina) or 0
    stamina.MaxStaminaTough = HunterStamina_GetMaxStaminaTough:call(HunterStamina) or 1
    stamina.StaminaLimit = HunterStamina_GetStaminaLimit:call(HunterStamina) or 1
    stamina.AutoMaxReduceTimer = HunterStamina_GetAutoMaxReduceTimer:call(HunterStamina)

    _M.HunterData.StaminaData = stamina
end

local Wp10Insect_Hunter = Core.TypeField("app.Wp10Insect", "_Hunter")
local Wp10Insect_Stamina = Core.TypeField("app.Wp10Insect", "Stamina")
local ValueHolderF_Value = Core.TypeField("app.cValueHolderF", "_Value")
local ValueHolderF_MaxValue = Core.TypeField("app.cValueHolderF", "MaxValue")
local ValueHolderF_DefaultValue = Core.TypeField("app.cValueHolderF", "DefaultValue")
local ValueHolderF_calcValueRate = Core.TypeMethod("app.cValueHolderF", "calcValueRate()")

local NullableSingle_HasValue = Core.TypeField("System.Nullable`1<System.Single>", "_HasValue")
local NullableSingle_Value = Core.TypeField("System.Nullable`1<System.Single>", "_Value")

---@param Insect app.Wp10Insect
---@param Hunter app.HunterCharacter
---@param Stamina app.cValueHolderF
function _M.UpdateInsectStamina(Insect)
    local Hunter = Wp10Insect_Hunter:get_data(Insect)
    if Hunter ~= _M.HunterData.Hunter then
        return
    end
    local InsectStamina = Wp10Insect_Stamina:get_data(Insect)

    local stamina = _M.HunterData.InsectStaminaData

    stamina.Stamina = InsectStamina._Value
    -- stamina.Default = InsectStamina.DefaultValue
    
    local max = ValueHolderF_MaxValue:get_data(InsectStamina)
    if NullableSingle_HasValue:get_data(max) then
        stamina.MaxStamina = NullableSingle_Value:get_data(max)
    else
        stamina.MaxStamina = ValueHolderF_DefaultValue:get_data(InsectStamina)
    end
    stamina.Ratio = ValueHolderF_calcValueRate:call(InsectStamina)

    _M.HunterData.InsectStaminaData = stamina
end

---@param WeaponHandling app.cHunterWeaponHandlingBase
function _M.UpdateWeaponHandling(WeaponHandling)
    -- 玩家可以切换武器
    -- if WeaponHandling ~= _M.HunterData.WeaponHandling then
    --     return
    -- end
    
    if _M.HunterData.WeaponType == CONST.WeaponType.DualBlades then
        _M.UpdateDualBladesBuffs(WeaponHandling)
    elseif _M.HunterData.WeaponType == CONST.WeaponType.LongSword then
        _M.UpdateLongSwordBuffs(WeaponHandling)
    elseif _M.HunterData.WeaponType == CONST.WeaponType.SwitchAxe then
        _M.UpdateSwitchAxeBuffs(WeaponHandling)
    elseif _M.HunterData.WeaponType == CONST.WeaponType.ChargeBlade then
        _M.UpdateChargeBladeBuffs(WeaponHandling)
    elseif _M.HunterData.WeaponType == CONST.WeaponType.InsectGlaive then
        _M.UpdateInsectGlaiveBuffs(WeaponHandling)
    end
end

-- TODO: Hide Sub Weapon Buffs

-- TODO: Debuff

local JustDodgeName = Core.GetLocalizedText(Core.NewGuid("ffe95f97-5827-470b-b9e6-776b73ecc0bf"))

---@param WeaponHandling app.cHunterWp02Handling
function _M.UpdateDualBladesBuffs(WeaponHandling)
    local param = WeaponHandling._ActionParam
    
    local KEY = "DualBladesJustDodgeBuff"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = JustDodgeName
        _M.WeaponBuffData[KEY].MaxTimer = param._JustSuccessBuffTime
    end
    _M.WeaponBuffData[KEY].Timer = _M.WeaponBuffData[KEY].MaxTimer - WeaponHandling:get_field("_MikiriBuffTimer")
    _M.WeaponBuffData[KEY].Activated = WeaponHandling:get_field("<IsMikiriBuff>k__BackingField")
end

---@param WeaponHandling app.cHunterWp03Handling
function _M.UpdateLongSwordBuffs(WeaponHandling)
    local param = WeaponHandling._ActionParam

    local KEY = "LongSwordRenkiRecover"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = "Renki Recover Buff"
        _M.WeaponBuffData[KEY].MaxTimer = param._RenkiAutoRecoverIai._RecoverTime
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling:get_field("_IaiRenkiAutoRecoverTimerIai")
    _M.WeaponBuffData[KEY].Activated = WeaponHandling:call("get_IsRenkiAutoRecover()")

    local auraLevel = WeaponHandling:get_AuraLevel()
    local time = WeaponHandling:get_AuraGauge():get_Value()
    
    local WHITE = "LongSwordWhiteGauge"
    local YELLOW = "LongSwordYellowGauge"
    local RED = "LongSwordRedGauge"
    if _M.WeaponBuffData[WHITE] == nil then
        _M.WeaponBuffData[WHITE] = NewBuffStatus()
        _M.WeaponBuffData[WHITE].Name = "White Gauge"
        _M.WeaponBuffData[WHITE].MaxTimer = param._AuraTime._WhiteTime + param._AuraStopTime
    end
    if _M.WeaponBuffData[YELLOW] == nil then
        _M.WeaponBuffData[YELLOW] = NewBuffStatus()
        _M.WeaponBuffData[YELLOW].Name = "Yellow Gauge"
        _M.WeaponBuffData[YELLOW].MaxTimer = param._AuraTime._YellowTime + param._AuraStopTime
    end
    if _M.WeaponBuffData[RED] == nil then
        _M.WeaponBuffData[RED] = NewBuffStatus()
        _M.WeaponBuffData[RED].Name = "Red Gauge"
        _M.WeaponBuffData[RED].MaxTimer = param._AuraTime._RedTime + param._AuraStopTime
    end
    if auraLevel == 2 then
        _M.WeaponBuffData[WHITE].Timer = time + WeaponHandling._AuraStopTimer
        _M.WeaponBuffData[WHITE].Activated = true
        _M.WeaponBuffData[YELLOW].Timer = 0
        _M.WeaponBuffData[YELLOW].Activated = false
        _M.WeaponBuffData[RED].Timer = 0
        _M.WeaponBuffData[RED].Activated = false
    elseif auraLevel == 3 then
        _M.WeaponBuffData[YELLOW].Timer = time + WeaponHandling._AuraStopTimer
        _M.WeaponBuffData[YELLOW].Activated = true
        _M.WeaponBuffData[WHITE].Timer = 0
        _M.WeaponBuffData[WHITE].Activated = false
        _M.WeaponBuffData[RED].Timer = 0
        _M.WeaponBuffData[RED].Activated = false
    elseif auraLevel == 4 then
        _M.WeaponBuffData[RED].Timer = time + WeaponHandling._AuraStopTimer
        _M.WeaponBuffData[RED].Activated = true
        _M.WeaponBuffData[WHITE].Timer = 0
        _M.WeaponBuffData[WHITE].Activated = false
        _M.WeaponBuffData[YELLOW].Timer = 0
        _M.WeaponBuffData[YELLOW].Activated = false
    else
        _M.WeaponBuffData[WHITE].Timer = 0
        _M.WeaponBuffData[WHITE].Activated = false
        _M.WeaponBuffData[YELLOW].Timer = 0
        _M.WeaponBuffData[YELLOW].Activated = false
        _M.WeaponBuffData[RED].Timer = 0
        _M.WeaponBuffData[RED].Activated = false
    end
end

local SAAxeEnhancedName = Core.GetLocalizedText(Core.NewGuid("f3d2f34f-24e7-4f3b-8679-b42f2234076c"))
local SASwordAwakeName = Core.GetLocalizedText(Core.NewGuid("75324dab-9992-4641-9db8-8a73de2be963"))

---@param WeaponHandling app.cHunterWp08Handling
function _M.UpdateSwitchAxeBuffs(WeaponHandling)
    local param = Core.GetPlayerManager()._Catalog:get_Wp08ActionParam()
    
    local KEY = "SlashAxeSwordAwake"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = SASwordAwakeName
        _M.WeaponBuffData[KEY].MaxTimer = param._SwordAwakeTime
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling._SwordAwakeTimer
    _M.WeaponBuffData[KEY].Activated = _M.WeaponBuffData[KEY].Timer > 0

    local KEY = "SlashAxeAxeEnhanced"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = SAAxeEnhancedName
        _M.WeaponBuffData[KEY].MaxTimer = param._AxeEnhancedTime
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling._AxeEnhancedTimer
    _M.WeaponBuffData[KEY].Activated = _M.WeaponBuffData[KEY].Timer > 0
end

local CBShieldEnhanceName = Core.GetLocalizedText(Core.NewGuid("20829729-8d95-4a23-a2c9-4d2f010ad44a"))
local CBSwordEnhanceName = Core.GetLocalizedText(Core.NewGuid("ce8c53ed-229e-4e50-b3ef-8049ede62125"))
local CBAxeEnhanceName = Core.GetLocalizedText(Core.NewGuid("ed792e69-633d-4bb2-9faf-0ccc2dd6221a"))

---@param WeaponHandling app.cHunterWp09Handling
function _M.UpdateChargeBladeBuffs(WeaponHandling)
    local param = Core.GetPlayerManager()._Catalog:get_Wp09ActionParam()
    
    local KEY = "ChargeBladeShieldEnhanced"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = CBShieldEnhanceName
        _M.WeaponBuffData[KEY].MaxTimer = param._ShieldEnhance_MaxTime
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling._ShieldEnhancedTimer
    _M.WeaponBuffData[KEY].Activated = _M.WeaponBuffData[KEY].Timer > 0

    local KEY = "ChargeBladeSwordEnhanced"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = CBSwordEnhanceName
        _M.WeaponBuffData[KEY].MaxTimer = param._SwordEnhance_Time
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling._SwordEnhancedTimer
    _M.WeaponBuffData[KEY].Activated = _M.WeaponBuffData[KEY].Timer > 0

    local KEY = "ChargeBladeAxeEnhanced"
    if _M.WeaponBuffData[KEY] == nil then
        _M.WeaponBuffData[KEY] = NewBuffStatus()
        _M.WeaponBuffData[KEY].Name = CBAxeEnhanceName
        _M.WeaponBuffData[KEY].MaxTimer = param._AxeEnhance_Time
    end
    _M.WeaponBuffData[KEY].Timer = WeaponHandling._AxeEnhancedTimer
    _M.WeaponBuffData[KEY].Activated = _M.WeaponBuffData[KEY].Timer > 0
end

---@param WeaponHandling app.cHunterWp10Handling
function _M.UpdateInsectGlaiveBuffs(WeaponHandling)
    local param = WeaponHandling._ActionParam
    
    local triple = WeaponHandling.TrippleUpTimer:get_Value()

    local TRIPLE = "InsectGlaiveTriple"
    local RED = "InsectGlaiveRed"
    local WHITE = "InsectGlaiveWhite"
    local ORANGE = "InsectGlaiveOrange"
    
    if _M.WeaponBuffData[TRIPLE] == nil then
        _M.WeaponBuffData[TRIPLE] = NewBuffStatus()
        _M.WeaponBuffData[TRIPLE].Name = "Triple"
        _M.WeaponBuffData[TRIPLE].MaxTimer = param._ExtractTimerTripple
    end
    if _M.WeaponBuffData[RED] == nil then
        _M.WeaponBuffData[RED] = NewBuffStatus()
        _M.WeaponBuffData[RED].Name = "Red"
        _M.WeaponBuffData[RED].MaxTimer = param._ExtractTimerRed
    end
    if _M.WeaponBuffData[WHITE] == nil then
        _M.WeaponBuffData[WHITE] = NewBuffStatus()
        _M.WeaponBuffData[WHITE].Name = "White"
        _M.WeaponBuffData[WHITE].MaxTimer = param._ExtractTimerWhite
    end
    if _M.WeaponBuffData[ORANGE] == nil then
        _M.WeaponBuffData[ORANGE] = NewBuffStatus()
        _M.WeaponBuffData[ORANGE].Name = "Orange"
        _M.WeaponBuffData[ORANGE].MaxTimer = param._ExtractTimerOrange
    end

    local isTrippleUp = WeaponHandling:get_IsTrippleUp()
    -- todo fixme 神经病，飞天螺旋斩后 三灯计时器不会清空？？
    if isTrippleUp then
        _M.WeaponBuffData[RED].Timer = 0
        _M.WeaponBuffData[RED].Activated = false
        _M.WeaponBuffData[WHITE].Timer = 0
        _M.WeaponBuffData[WHITE].Activated = false
        _M.WeaponBuffData[ORANGE].Timer = 0
        _M.WeaponBuffData[ORANGE].Activated = false

        _M.WeaponBuffData[TRIPLE].Timer = triple
        _M.WeaponBuffData[TRIPLE].Activated = true
    else
        _M.WeaponBuffData[RED].Timer = WeaponHandling.ExtractTimer:get_Item(0):get_Value()
        _M.WeaponBuffData[RED].Activated = _M.WeaponBuffData[RED].Timer > 0
        _M.WeaponBuffData[WHITE].Timer = WeaponHandling.ExtractTimer:get_Item(1):get_Value()
        _M.WeaponBuffData[WHITE].Activated = _M.WeaponBuffData[WHITE].Timer > 0
        _M.WeaponBuffData[ORANGE].Timer = WeaponHandling.ExtractTimer:get_Item(2):get_Value()
        _M.WeaponBuffData[ORANGE].Activated = _M.WeaponBuffData[ORANGE].Timer > 0

        _M.WeaponBuffData[TRIPLE].Timer = 0
        _M.WeaponBuffData[TRIPLE].Activated = false
    end
end

---@param status app.cHunterStatus
-- function _M.UpdateHunterStatus(status)
--     _M.UpdateHunterItemBuff(status._ItemBuff)
--     _M.UpdateHunterSkills(status._Skill)
-- end

---@param ctrl app.mcActiveSkillController
function _M.UpdateASkillController(ctrl)
    if ctrl._Hunter ~= _M.HunterData.Hunter then
        return
    end
    Core.ForEach(ctrl._ActiveSkills, function (askill, i)
        _M.UpdateASkill(askill, i)
    end)
end

---@param askill app.mcActiveSkillController.cActiveSkill
---@param i integer
function _M.UpdateASkill(askill, i)
    if _M.ASkillData[i] == nil then
        _M.ASkillData[i] = NewBuffStatus()
        _M.ASkillData[i].Name = Core.GetASkillName(i)
    end

    local using = askill:get_IsUse()
    local cooling = not askill:get_IsCanUseTrigger()
    if using then
        _M.ASkillData[i].Timer = askill:get_Timer()
        _M.ASkillData[i].MaxTimer = askill:get_MaxEffectiveTime()
    elseif cooling then
        _M.ASkillData[i].Timer = askill:get_Timer()
        _M.ASkillData[i].MaxTimer = askill:get_CoolTimer()
    else
        _M.ASkillData[i].Timer = 0
        _M.ASkillData[i].MaxTimer = 1
    end
    _M.ASkillData[i].Activated = _M.ASkillData[i].Timer > 0
end

local GetSkillLevelFunc = Core.TypeMethod("app.cHunterSkill", "getSkillLevel(app.HunterDef.Skill, System.Boolean, System.Boolean)") 

local InfoGet_Skill = Core.TypeField("app.cHunterSkillParamInfo.cInfo", "_Skill")
local InfoGet_Timer = Core.TypeField("app.cHunterSkillParamInfo.cInfo", "_Timer")
local InfoGet_MaxTimer = Core.TypeField("app.cHunterSkillParamInfo.cInfo", "_MaxTimer")
---@param hunterSkill app.cHunterSkill
---@param info app.cHunterSkillParamInfo.cInfo
function _M.UpdateHunterSkillInfo(hunterSkill, info)
    local skill = InfoGet_Skill:get_data(info)
    if _M.SkillData[skill] == nil then
        _M.SkillData[skill] = NewBuffStatus()
        _M.SkillData[skill].Level = GetSkillLevelFunc:call(hunterSkill, skill, false, false)
        _M.SkillData[skill].Name = Core.GetSkillName(skill, _M.SkillData[skill].Level) .. tostring(skill)
    end
    _M.SkillData[skill].Timer = InfoGet_Timer:get_data(info)
    _M.SkillData[skill].MaxTimer = InfoGet_MaxTimer:get_data(info)
    _M.SkillData[skill].Activated = _M.SkillData[skill].Timer > 0
end

---@param hunterSkill app.cHunterSkill
---@param skill app.HunterDef.Skill
function _M.UpdateHunterSkill(hunterSkill, skill, activated, timer, maxTimer)
    if timer == nil then
        timer = 1
    end
    if maxTimer == nil then
        maxTimer = timer
    end
    if _M.SkillData[skill] == nil then
        _M.SkillData[skill] = NewBuffStatus()
        _M.SkillData[skill].Level = GetSkillLevelFunc:call(hunterSkill, skill, false, false)
        _M.SkillData[skill].Name = Core.GetSkillName(skill, _M.SkillData[skill].Level) .. tostring(skill)
    end
    _M.SkillData[skill].Timer = timer
    _M.SkillData[skill].MaxTimer = maxTimer
    _M.SkillData[skill].Activated = activated
end

---@param hunterSkill app.cHunterSkill
---@param skill app.HunterDef.Skill
function _M.UpdateCustomHunterSkill(hunterSkill, name, activated, timer, maxTimer)
    if timer == nil then
        timer = 1
    end
    if maxTimer == nil then
        maxTimer = timer
    end
    if _M.SkillData[name] == nil then
        _M.SkillData[name] = NewBuffStatus()
        _M.SkillData[name].Level = 1
        _M.SkillData[name].Name = name
    end
    _M.SkillData[name].Timer = timer
    _M.SkillData[name].MaxTimer = maxTimer
    _M.SkillData[name].Activated = activated
end

local ParamGet_ToishiBoostInfo = Core.TypeField("app.cHunterSkillParamInfo", "_ToishiBoostInfo") -- 刚刃打磨
local ParamGet_RebellionInfo = Core.TypeField("app.cHunterSkillParamInfo", "_RebellionInfo")
local ParamGet_ElementConvertInfo = Core.TypeField("app.cHunterSkillParamInfo", "_ElementConvertInfo") -- 属性吸收
local ParamGet_RyukiInfo = Core.TypeField("app.cHunterSkillParamInfo", "_RyukiInfo") -- 属性变换
local ParamGet_MusclemanInfo = Core.TypeField("app.cHunterSkillParamInfo", "_MusclemanInfo")
local ParamGet_BarbarianInfo = Core.TypeField("app.cHunterSkillParamInfo", "_BarbarianInfo")
local ParamGet_PowerAwakeInfo = Core.TypeField("app.cHunterSkillParamInfo", "_PowerAwakeInfo") -- 力解
local ParamGet_RyunyuInfo = Core.TypeField("app.cHunterSkillParamInfo", "_RyunyuInfo")
local ParamGet_ContinuousAttackInfo = Core.TypeField("app.cHunterSkillParamInfo", "_ContinuousAttackInfo") -- 连击
local ParamGet_GuardianAreaInfo = Core.TypeField("app.cHunterSkillParamInfo", "_GuardianAreaInfo") -- 护龙之守护
local ParamGet_ResentmentInfo = Core.TypeField("app.cHunterSkillParamInfo", "_ResentmentInfo") -- 怨恨
local ParamGet_KnightInfo = Core.TypeField("app.cHunterSkillParamInfo", "_KnightInfo") -- 攻击守势
local ParamGet_MoraleInfo = Core.TypeField("app.cHunterSkillParamInfo", "_MoraleInfo")
local ParamGet_LuckInfo = Core.TypeField("app.cHunterSkillParamInfo", "_LuckInfo")
local ParamGet_HagitoriMasterInfo = Core.TypeField("app.cHunterSkillParamInfo", "_HagitoriMasterInfo")
local ParamGet_CaptureMasterInfo = Core.TypeField("app.cHunterSkillParamInfo", "_CaptureMasterInfo")
local ParamGet_BattoWazaInfo = Core.TypeField("app.cHunterSkillParamInfo", "_BattoWazaInfo") -- 拔刀术技
local ParamGet_HunkiInfo = Core.TypeField("app.cHunterSkillParamInfo", "_HunkiInfo") -- 毒伤害强化
local ParamGet_SlidingPowerUpInfo = Core.TypeField("app.cHunterSkillParamInfo", "_SlidingPowerUpInfo")
local ParamGet_CounterAttackInfo = Core.TypeField("app.cHunterSkillParamInfo", "_CounterAttackInfo") -- 逆袭
local ParamGet_DisasterInfo = Core.TypeField("app.cHunterSkillParamInfo", "_DisasterInfo") -- 因祸得福
local ParamGet_MantleStrengtheningInfo = Core.TypeField("app.cHunterSkillParamInfo", "_MantleStrengtheningInfo")
local ParamGet_BegindAttackInfo = Core.TypeField("app.cHunterSkillParamInfo", "_BegindAttackInfo") -- 急袭
local ParamGet_YellInfo = Core.TypeField("app.cHunterSkillParamInfo", "_YellInfo")
local ParamGet_TechnicalAttackInfo = Core.TypeField("app.cHunterSkillParamInfo", "_TechnicalAttack_Info") -- 巧击

---@param skill app.cHunterSkill
function _M.UpdateHunterSkills(skill)
    local otomoSkillTimer = skill._OtomoMusicSkillTimer

    Core.ForEach(otomoSkillTimer, function (timer, i)
        if _M.OtomoSkillData[i] == nil then
            _M.OtomoSkillData[i] = NewBuffStatus()
            _M.OtomoSkillData[i].Name = OtomoSkillTypeNames[i] -- Core.GetOtomoSkillName(i)
        end
        _M.OtomoSkillData[i].Timer = timer
        if timer > _M.OtomoSkillData[i].MaxTimer then
            _M.OtomoSkillData[i].MaxTimer = timer
        end
        _M.OtomoSkillData[i].Activated = timer > 0
    end)
    
    local musicSkill = skill._Wp05MusicSkill
    local musicTimer = musicSkill._SkillTimer

    Core.ForEach(musicTimer, function (timer, i)
        if _M.MuiscSkillData[i] == nil then
            _M.MuiscSkillData[i] = NewBuffStatus()
            _M.MuiscSkillData[i].Name = Core.GetMusicSkillName(i)
        end
        _M.MuiscSkillData[i].Timer = timer
        if timer > _M.MuiscSkillData[i].MaxTimer then
            _M.MuiscSkillData[i].MaxTimer = timer
        end

        _M.MuiscSkillData[i].Activated = _M.MuiscSkillData[i].Timer > 0
        -- TODO: FIXME 不知道笛子的自我强化是在哪里标记的失效
        -- _M.MuiscSkillData[i].Activated = musicSkill:call("isEnable(app.Wp05Def.WP05_MUSIC_SKILL_TYPE)", i)
    end)
    
    -- 狂龙病
    local status = skill:get_Status()
    local frenzy = status._BadConditions._Frenzy
    if frenzy._State == 0 then
        -- Infect
        _M.UpdateCustomHunterSkill(skill, "Frenzy Overcome Point", true, frenzy._OvercomePoint, frenzy._OvercomeTargetPoint)
        _M.UpdateCustomHunterSkill(skill, "Frenzy Timer", true, frenzy._DurationTimer, frenzy._DurationTime)

        _M.UpdateCustomHunterSkill(skill, "Frenzy Infected", false, 0, 0)
        _M.UpdateHunterSkill(skill, 194, false, 0, 0) -- 黑蚀龙之力
    elseif frenzy._State == 1 then
        -- Outbreak 克服失败
        _M.UpdateCustomHunterSkill(skill, "Frenzy Infected", true, frenzy._DurationTimer, frenzy._DurationTime)
        
        _M.UpdateCustomHunterSkill(skill, "Frenzy Overcome Point", false, 0, 0)
        _M.UpdateCustomHunterSkill(skill, "Frenzy Timer", false, 0, 0)
        _M.UpdateHunterSkill(skill, 194, false, 0, 0) -- 黑蚀龙之力
    elseif frenzy._State == 2 then
        -- Overcome
        _M.UpdateHunterSkill(skill, 194, true, frenzy._DurationTimer, frenzy._DurationTime)
        
        _M.UpdateCustomHunterSkill(skill, "Frenzy Overcome Point", false, 0, 0)
        _M.UpdateCustomHunterSkill(skill, "Frenzy Timer", false, 0, 0)
        _M.UpdateCustomHunterSkill(skill, "Frenzy Infected", false, 0, 0)
    end

    -- local HasMaxHPSkill = skill:call("checkSkillActive(app.HunterDef.Skill)", 60) -- 无伤
    -- if HasMaxHPSkill then
    --     local mgr = status:get_Health():get_HealthMgr()
    --     local isMaxHP = mgr:get_Health() == mgr:get_MaxHealth()
    --     _M.UpdateHunterSkill(skill, 60, isMaxHP)
    -- else
    --     _M.UpdateHunterSkill(skill, 60, false)
    -- end


    _M.UpdateHunterSkill(skill, 59, skill._IsActiveChallenger) -- 挑战者
    -- _ViolentIntervalTime
    local infos = skill._HunterSkillParamInfo
    
    _M.UpdateHunterSkill(skill, 60, infos._IsActiveFullCharge)
    
    -- 抖擞
    if infos._IsActiveKonshin then
        _M.UpdateHunterSkill(skill, 65, true, 2-infos._KonshinStaminaUseTime, 2)
        _M.UpdateCustomHunterSkill(skill, "Konshin Timer", false, 0, 0)
    else
        _M.UpdateHunterSkill(skill, 65, false, 0, 0)
        _M.UpdateCustomHunterSkill(skill, "Konshin Timer", true, infos._KonshinStaminaContinueTime, 3)
    end

    _M.UpdateHunterSkill(skill, 101, infos._IsAdrenalineRush) -- 火场怪力

    -- 锁刃龙之饥饿，累积需要5hit，每hit间隔1s，不能超过5s。达到5hit后回血。
    -- local heal = skill:getSkillAccHealValue(app.WeaponDef.TYPE)
    _M.UpdateCustomHunterSkill(skill, "AccHeal", true, infos._AccHealHitCount, 5)
    local accTimer = infos._AccHealContinueTime
    if accTimer > 0 then
        if accTimer >= 4.0 then
            _M.UpdateCustomHunterSkill(skill, "AccHealInterval", true, 5 - infos._AccHealContinueTime, 1)
        else
            _M.UpdateCustomHunterSkill(skill, "AccHealInterval", false, 0, 0)
        end
        _M.UpdateCustomHunterSkill(skill, "AccHealTime", true, infos._AccHealContinueTime)
    else
        _M.UpdateCustomHunterSkill(skill, "AccHealInterval", false, 0, 0)
        _M.UpdateCustomHunterSkill(skill, "AccHealTime", false, 0, 0)
    end
    -- _M.UpdateCustomHunterSkill(skill, "Violent", true, skill._ViolentIntervalTime)
    -- _M.UpdateCustomHunterSkill(skill, "ScorchingHeatInterval", true, skill._ScorchingHeatIntervalTime)
    -- _M.UpdateCustomHunterSkill(skill, "ScorchingHeatNoHit", true, skill._ScorchingHeatNoHitCount)
    -- _M.UpdateCustomHunterSkill(skill, "_MoraleRequest", skill._MoraleRequest)
    -- _M.UpdateCustomHunterSkill(skill, "_IsActiveGuts", skill._IsActiveGuts)
    -- _M.UpdateCustomHunterSkill(skill, "_IsUsedGuts", skill._IsUsedGuts)
    -- _M.UpdateCustomHunterSkill(skill, "_MoraleRequest", skill._MoraleRequest)
    -- _M.UpdateCustomHunterSkill(skill, "_SlidingPowerUpStartTime", true, skill._SlidingPowerUpStartTime)
    -- _M.UpdateCustomHunterSkill(skill, "_AccHealHitCount", true, skill._AccHealHitCount)
    -- _M.UpdateCustomHunterSkill(skill, "_AccHealContinueTime", true, skill._AccHealContinueTime)
    -- _M.UpdateCustomHunterSkill(skill, "_IsActiveKatsu", skill._IsActiveKatsu)
    -- _M.UpdateCustomHunterSkill(skill, "_FortitudeDieCount", true, skill._FortitudeDieCount)
    -- _M.UpdateCustomHunterSkill(skill, "_FortitudeDieRequest", skill._FortitudeDieRequest)
    -- _M.UpdateCustomHunterSkill(skill, "_IsActiveFullCharge", skill._IsActiveFullCharge)
    _M.UpdateCustomHunterSkill(skill, "_StabbingIntervalTime", true, infos._StabbingIntervalTime)
    -- _M.UpdateCustomHunterSkill(skill, "_IsCanBattoPower", skill._IsCanBattoPower)

    _M.UpdateHunterSkillInfo(skill, ParamGet_ToishiBoostInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_RebellionInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_ElementConvertInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_RyukiInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_MusclemanInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_BarbarianInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_PowerAwakeInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_RyunyuInfo:get_data(infos))

    local ContinuousAttack = ParamGet_ContinuousAttackInfo:get_data(infos)
    _M.UpdateHunterSkillInfo(skill, ContinuousAttack)
    _M.SkillData[115].BuffLevel = 1 -- 连击
    if ContinuousAttack._HitCount >= 5 then
        _M.SkillData[115].BuffLevel = 2
    end
    _M.SkillData[115].Name = Core.GetSkillName(115, _M.SkillData[115].Level) .. string.format("Lv%d", _M.SkillData[115].BuffLevel) .. tostring(115)
    
    _M.UpdateHunterSkillInfo(skill, ParamGet_GuardianAreaInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_ResentmentInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_KnightInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_MoraleInfo:get_data(infos))
    -- _M.UpdateHunterSkillInfo(skill, ParamGet_LuckInfo:get_data(infos))
    -- _M.UpdateHunterSkillInfo(skill, ParamGet_HagitoriMasterInfo:get_data(infos))
    -- _M.UpdateHunterSkillInfo(skill, ParamGet_CaptureMasterInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_BattoWazaInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_HunkiInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_SlidingPowerUpInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_CounterAttackInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_DisasterInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_MantleStrengtheningInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_BegindAttackInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_YellInfo:get_data(infos))
    _M.UpdateHunterSkillInfo(skill, ParamGet_TechnicalAttackInfo:get_data(infos))
end

local ItemIDs = {
    Kairiki = 125, -- 怪力种子
    KairikiG = 168, -- 怪力药丸
    Nintai = 126, -- 忍耐种子
    NintaiG = 171, -- 忍耐药丸

    KijinPowder = 175, -- 鬼人粉尘
    KoukaPowder = 176, -- 硬化粉尘
    KijinAmmo = 412, -- 鬼人弹
    KoukaAmmo = 413, -- 硬化弹

    DashJuice = 163,
    Immunizer = 164,

    HotDrink = 166,
    CoolerDrink = 165,

    KijinDrink = 167, -- 鬼人药
    KijinDrinkG = 169,
    KoukaDrink = 170, -- 硬化药
    KoukaDrinkG = 172,
}

function _M.UpdateItemBuff(name, timer, max)
    if _M.ItemBuffData[name] == nil then
        _M.ItemBuffData[name] = NewBuffStatus()
        if ItemIDs[name] and ItemIDs[name] ~= -1 then
            _M.ItemBuffData[name].Name = Core.GetItemName(ItemIDs[name])
        end
    end
    if max then
        _M.ItemBuffData[name].MaxTimer = max
    else
        if timer > _M.ItemBuffData[name].MaxTimer then
            _M.ItemBuffData[name].MaxTimer = timer
        end
    end
    _M.ItemBuffData[name].Timer = timer
    _M.ItemBuffData[name].Activated = timer > 0
end

---@param item app.cHunterItemBuff
function _M.UpdateHunterItemBuff(item)
    _M.UpdateItemBuff("Kairiki", item._Kairiki_Timer, item._Kairiki_MaxTime)
    _M.UpdateItemBuff("KairikiG", item._Kairiki_G_Timer, item._Kairiki_G_MaxTime)
    _M.UpdateItemBuff("KijinAmmo", item._KijinAmmo_Timer)
    _M.UpdateItemBuff("KijinPowder", item._KijinPowder_Timer, item._KijinPowder_MaxTime)
    _M.UpdateItemBuff("Nintai", item._Nintai_Timer, item._Nintai_MaxTime)
    _M.UpdateItemBuff("NintaiG", item._Nintai_G_Timer, item._Nintai_G_MaxTime)
    _M.UpdateItemBuff("KoukaAmmo", item._KoukaAmmo_Timer)
    _M.UpdateItemBuff("KoukaPowder", item._KoukaPowder_Timer, item._KoukaPowder_MaxTime)
    _M.UpdateItemBuff("DashJuice", item._DashJuice_Timer, item._DashJuice_MaxTime)
    _M.UpdateItemBuff("Immunizer", item._Immunizer_Timer, item._Immunizer_MaxTime)
    _M.UpdateItemBuff("HotDrink", item._HotDrink_Timer, item._HotDrink_MaxTime)
    _M.UpdateItemBuff("CoolerDrink", item._CoolerDrink_Timer, item._CoolerDrink_MaxTime)
    _M.UpdateItemBuff("KijinDrink", item._KijinDrink._Timer, item._KijinDrink._MaxTime)
    _M.UpdateItemBuff("KijinDrinkG", item._KijinDrink_G._Timer, item._KijinDrink_G._MaxTime)
    _M.UpdateItemBuff("KoukaDrink", item._KoukaDrink._Timer, item._KoukaDrink._MaxTime)
    _M.UpdateItemBuff("KoukaDrinkG", item._KoukaDrink_G._Timer, item._KoukaDrink_G._MaxTime)
end

return _M
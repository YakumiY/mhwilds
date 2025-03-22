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
local StatusData = require("mhwilds_overlay.status.data")

---@type ReporterModuleType
local _M = {}

---@class SkillReport
---@field Damage number
---@field Physical number
---@field Elemental number
---@field HitCount number
---@field CriticalCount number
---@field NegCriticalCount number
---@field PhysicsExploitCount number
---@field MindEyeCount number
---@field ElementalHitCount number
---@field ElementalExploitCount number
---@field ElementCriticalCount number
---@field ElementNegCriticalCount number

---@return SkillReport
local function NewSkillReport()
    return {
        Damage = 0,
        Physical = 0,
        Elemental = 0,
        HitCount = 0,
        CriticalCount = 0,
        NegCriticalCount = 0,
        PhysicsExploitCount = 0,
        MindEyeCount = 0,
        ElementalHitCount = 0,
        ElementalExploitCount = 0,
        ElementCriticalCount = 0,
        ElementNegCriticalCount = 0,
    }
end

---@class ReporterModuleType
---@field Reports table<app.HunterDef.Skill, SkillReport>

-- skill data
-- skill -> counter
---@alias ReporterSkillCounter table<app.HunterDef.Skill, SkillReport>

-- buff covered hit type data
-- skill -> hit type -> counter
---@alias ReporterBuffedHitCounter table<app.HunterDef.Skill, table<string, integer>>

local function RecordReportValue(key, type, value)
    if _M.Reports[key] == nil then
        _M.Reports[key] = NewSkillReport()
    end
    if _M.Reports[key][type] == nil then
        _M.Reports[key][type] = 0
    end

    if value == nil then
        value = 1
    end
    
    _M.Reports[key][type] = _M.Reports[key][type] + value
end

function _M.ClearData()
    _M.TotalHitCount = 0
    _M.TotalDamage = 0
    _M.Reports = {}
end

_M.ClearData()

function _M.RecordCounter(skillName, type, value)
    RecordReportValue(_M.Counter, skillName, type, value)
end

local function RecordBuffCoveredHitCounter(skillName, hitType)
    RecordReportValue(skillName, hitType, 1)
end

local function RecordBuffCoveredDamage(skillName, total, physical, elemental)
    RecordReportValue(skillName, "Damage", total)
    RecordReportValue(skillName, "Physical", physical)
    RecordReportValue(skillName, "Elemental", elemental)
end

---@param calcDamage app.cEnemyStockDamage.cCalcDamage
---@param data table<any, BuffStatus>
local function RecordBuffedCalcDamage(calcDamage, data, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    local FinalDamage = calcDamage.FinalDamage
    local Physical = calcDamage.Physical
    local Elemental = calcDamage.Element

    for _, status in pairs(data) do
        local activated = status.Activated
        local skillName = status.Name
        if activated and skillName then
            RecordBuffCoveredHitCounter(skillName, "HitCount")
            RecordBuffCoveredDamage(skillName, FinalDamage, Physical, Elemental)
            -- if isCritical then
            --     -- 会心
            --     RecordBuffCoveredHitCounter(skillName, "CriticalCount")
            -- end
            if isPhysicsExploit then
                -- 弱点特效
                RecordBuffCoveredHitCounter(skillName, "PhysicsExploitCount")
            end
            if isMindEye then
                -- 心眼
                RecordBuffCoveredHitCounter(skillName, "MindEyeCount")
            end
            if isElement then
                RecordBuffCoveredHitCounter(skillName, "ElementalHitCount")
                if isElementExploit then
                    -- 弱点特效【属性】
                    RecordBuffCoveredHitCounter(skillName, "ElementalExploitCount")
                end
                -- if isCritical then
                --     -- 会心击【属性】
                --     RecordBuffCoveredHitCounter(skillName, "ElementCriticalCount")
                -- end
            end
            -- else
        --     RecordBuffCoveredHitCounter(skillName .. "NotCoveredHit")
        end
    end
end

local function RecordBuffedHitInfo(data, isCritical, isNegCritical)
    for _, status in pairs(data) do
        local activated = status.Activated
        local skillName = status.Name
        if activated and skillName then
            if isCritical then
                -- 会心
                RecordBuffCoveredHitCounter(skillName, "CriticalCount")
            end
            if isNegCritical then
                RecordBuffCoveredHitCounter(skillName, "NegCriticalCount")
            end
        end
    end
end

---@param calcDamage app.cEnemyStockDamage.cCalcDamage
function _M.RecordCalcDamage(calcDamage, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    _M.TotalDamage = _M.TotalDamage + calcDamage.FinalDamage
    RecordBuffedCalcDamage(calcDamage, StatusData.SkillData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    RecordBuffedCalcDamage(calcDamage, StatusData.MuiscSkillData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    RecordBuffedCalcDamage(calcDamage, StatusData.OtomoSkillData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    RecordBuffedCalcDamage(calcDamage, StatusData.ItemBuffData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    RecordBuffedCalcDamage(calcDamage, StatusData.ASkillData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
    RecordBuffedCalcDamage(calcDamage, StatusData.WeaponBuffData, isPhysicsExploit, isMindEye, isElement, isElementExploit)
end

function _M.RecordHitInfo(isCritical, isNegCritical)
    _M.TotalHitCount = _M.TotalHitCount + 1
    RecordBuffedHitInfo(StatusData.SkillData, isCritical, isNegCritical)
    RecordBuffedHitInfo(StatusData.MuiscSkillData, isCritical, isNegCritical)
    RecordBuffedHitInfo(StatusData.OtomoSkillData, isCritical, isNegCritical)
    RecordBuffedHitInfo(StatusData.ItemBuffData, isCritical, isNegCritical)
    RecordBuffedHitInfo(StatusData.ASkillData, isCritical, isNegCritical)
    RecordBuffedHitInfo(StatusData.WeaponBuffData, isCritical, isNegCritical)
end

function _M.RecordSkillAdditionalDamage(skillId, damage)
    if skillId <= 0 or damage <= 0 then
        return
    end
    local name = Core.GetSkillName(skillId, 1)
    Core.SendMessage("[%d]%s add dmg: %0.1f", skillId, name, damage)
    if not _M.Reports[name] then
        _M.Reports[name] = NewSkillReport()
    end
    _M.Reports[name].Damage = _M.Reports[name].Damage + damage
end

return _M
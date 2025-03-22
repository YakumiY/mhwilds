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
local OverlayData = require("mhwilds_overlay.data")
local Config = require("mhwilds_overlay.dps_chart.conf")

local _M = {}

_M.LastBuildCacheIndex = -1
_M.CurrentSampleIndex = 0

---@class DpsData
---@field Total number
---@field DPS number

---@alias DpsHistory table<integer, DpsData>

---@class DPSRecord
---@field MaxDPS number
---@field LastIndex integer
---@field FirstIndex integer
---@field DpsHistory DpsHistory

-- 记录角色总和的统计数据，实时DPS，保留60列（每10秒一列）
---@type table<Hunter, DPSRecord>
_M.HunterDpsRecord = {} -- Hunter -> {LastIndex, DpsData}, DpsData: {Index -> Total}, Index = math.floor(QuestElapsedTime / 10)

function _M.ClearData()
    _M.LastBuildCacheIndex = -1
    _M.HunterDpsRecord = {}
end

---@param attacker Hunter | Otomo
---@param enemyCtx EnemyContext
---@param isPlayer boolean
---@param totalDamage number|nil
function _M.InitDamageRecord(attacker, enemyCtx, isPlayer, totalDamage)
    -- we don't need otomo DPS curve chart
    if not isPlayer then return end

    if OverlayData.HunterInfo[attacker].WeaponType == nil then
        OverlayData.HunterInfo[attacker].WeaponType = attacker:get_Weapon()._WpType
    end

    local index = _M.CurrentSampleIndex
    if _M.HunterDpsRecord[attacker] == nil then
        _M.HunterDpsRecord[attacker] = {
            DpsHistory = {},
            FirstIndex = index,
        }
    end
    
    _M.HunterDpsRecord[attacker].LastIndex = index

    if _M.HunterDpsRecord[attacker].DpsHistory[index] == nil then
        _M.HunterDpsRecord[attacker].DpsHistory[index] = {
            Total = 0,
            DPS = 0,
        }
    end
end

---@param attacker Hunter|Otomo
---@param enemyCtx EnemyContext
---@param isPlayer boolean
function _M.HandleDamage(attacker, enemyCtx, isPlayer)
    if not isPlayer then return end

    _M.LastBuildCacheIndex = -1

    local index = _M.CurrentSampleIndex

    local hitTime = OverlayData.QuestStats.ElapsedTime - OverlayData.HunterInfo[attacker].FirstHitTime
    if hitTime < Config.SampleRate then
        hitTime = Config.SampleRate*1.5 -- grace first hit
    end

    local total = OverlayData.HunterDamageRecords[attacker].Total
    local dps = total / hitTime
    _M.HunterDpsRecord[attacker].DpsHistory[index].Total = total
    _M.HunterDpsRecord[attacker].DpsHistory[index].DPS = dps
    -- if not total then
    --     Core.SendMessage("ERROR: " .. tostring(OverlayData.GetHunterName(attacker)))
    --     total = 0
    -- end
    local questMax = OverlayData.QuestStats.MaxPlayerTotal
    -- if not questMax then
    --     Core.SendMessage("ERROR: Q.Max is nil")
    --     OverlayData.QuestStats.MaxPlayerTotal = 0
    -- end
    if total >questMax then
        OverlayData.QuestStats.MaxPlayerTotal = total
    end
    -- 不记录第一次攻击的 DPS，因为往往太高了
    if hitTime > Config.SampleRate and dps > OverlayData.QuestStats.MaxPlayerDPS then
        OverlayData.QuestStats.MaxPlayerDPS = dps
    end
end

local LastSampleRate = Config.SampleRate
local LastColumns = Config.ChartConfig.Columns
mod.OnUpdateBehavior(function ()
    if Config.ChartConfig.Columns ~= LastColumns then
        LastColumns = Config.ChartConfig.Columns

        _M.LastBuildCacheIndex = -1
    end
    if Config.SampleRate ~= LastSampleRate then
        LastSampleRate = Config.SampleRate

        _M.ClearData()
    end

    if OverlayData.QuestStats.ElapsedTime == nil then
        _M.CurrentSampleIndex = 0
    end
    if OverlayData.QuestStats.ElapsedTime > 0 or (Core.IsActiveQuest() or OverlayData.IsInTraningArea) then
        _M.CurrentSampleIndex = math.ceil(OverlayData.QuestStats.ElapsedTime / Config.SampleRate)
    else
        _M.CurrentSampleIndex = 0
    end
end)


return _M
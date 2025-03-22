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
local _ = _

local Core = require("_CatLib")
local Debug = require("_CatLib.debug")
local Draw = require("_CatLib.draw")
local CONST = require("_CatLib.const")


local mod = require("mhwilds_overlay.mod")
local OverlayData = require("mhwilds_overlay.data")
local ReporterData = require("mhwilds_overlay.reporter.data")

local _M = {}

function _M.ClearData()
    
end

---@param report SkillReport
local function PrintSkillReport(skill, report)
    return string.format("%s: %0.1f=(%0.1f+%0.1f) | %d Hits, %d Crits, %d Exploits", skill, report.Damage, report.Physical, report.Elemental, report.HitCount, report.CriticalCount, report.PhysicsExploitCount)
end

local function DrawReport()
    local counters = ReporterData.Counter

    local x = 600
    local y = 400
    for skill, data in pairs(ReporterData.Reports) do
        Draw.Text(x, y, 0xffffffff, PrintSkillReport(skill, data))
        y = y + 30
    end
end

mod.D2dRegister(function ()
    -- if mod.Config.Verbose then
    --     DrawReport()
    -- end
end, "Report")

return _M
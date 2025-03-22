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
local Core = require("_CatLib")
local CONST = require("_CatLib.const")

local mod = require("mhwilds_overlay.mod")

local ASkillController
local function GetASkillController()
    if not ASkillController then
        ASkillController = Core.GetPlayerCharacter():get_ASkillController()
    end
    return ASkillController
end

local ASkillCache = {
    Count = 0,
    Data = {},
}

mod.HookFunc("app.mcActiveSkillController", "updateMain()",
function (args)
    ---@type app.mcActiveSkillController
    local this = sdk.to_managed_object(args[2])
    if not this then return end


    local hunter = this._Hunter
    if not hunter or not hunter:get_IsMaster() then
        return
    end

    local skills = this:get_ActiveSkills()
    ASkillCache.Count = skills:get_Count()
    Core.ForEach(skills, function (skill, i)
        ASkillCache.Data[i] = {
            Timer = skill:get_Timer(),
            Cool = skill:get_CoolTimer(),
        }
    end)
end)

-- mod.OnFrame(function()
--     imgui.text("Size: " .. tostring(ASkillCache.Count))
--     for i, data in pairs(ASkillCache.Data) do
--         imgui.text("Timer: " .. tostring(data.Timer))
--         imgui.text("Cool: " .. tostring(data.Cool))
--     end
-- end)

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
local StatusData = require("mhwilds_overlay.status.data")

local _M = {}

mod.HookFunc("app.HunterCharacter", "doLateUpdateEnd()",
function (args)
    StatusData.Init()
    
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    StatusData.UpdateHunter(this)
end)

mod.HookFunc("app.cHunterHealth", "update(System.Single, System.Boolean)",
function (args)
    StatusData.Init()
    
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    StatusData.UpdateHunterHealth(this)
end)

mod.HookFunc("app.cHunterStamina", "update(System.Single)",
function (args)
    StatusData.Init()

    local this = sdk.to_managed_object(args[2])
    if not this then return end

    StatusData.UpdateHunterStamina(this)
end)

mod.HookFunc("app.Wp10Insect", "updateStamina()",
function (args)
    StatusData.Init()

    local this = sdk.to_managed_object(args[2])
    if not this then return end

    StatusData.UpdateInsectStamina(this)
end)

-- mod.HookFunc("app.cHunterStatus", "update(app.HunterCharacter)",
-- function (args)
--     local this = sdk.to_managed_object(args[2])
--     if not this then return end
--     if not this:get_IsMaster() then
--         return
--     end

--     local storage = thread.get_hook_storage()
--     storage["this"] = this
-- end, function (retval)
--     local storage = thread.get_hook_storage()
--     local this = storage["this"]
--     if this then
--         StatusData.UpdateHunterHealth(this:get_Health())
--         StatusData.UpdateHunterStamina(this:get_Stamina())
--     end

--     return retval
-- end)

-- 他妈的太难绷了，这个东西的update和hunter character不同步，甚至cHunterStatus和character都不同步
-- 然后不同步就算了，它的值会被置为-1
-- 于是如果hook在hunter character里，那读取到的值就会在正确值和-1之前反复横跳
-- why？而且甚至开瞄准模式会提高刷新率
-- 他妈的真的神人了
-- 甚至 itembuff 是直接挂在 status 里的也要在这里更新，不然就有可能拿到0
mod.HookFunc("app.HunterSkillUpdater", "lateUpdate()",
function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end

    local skill = this._HunterSkill
    if not skill then return end

    local status = skill:get_Status()
    if not status then return end
    if not status:get_IsMaster() then
        return
    end

    -- StatusData.UpdateHunterSkills(skill)
    StatusData.UpdateHunterItemBuff(status._ItemBuff)
    StatusData.UpdateHunterSkills(status._Skill)
end)

mod.HookFunc("app.mcActiveSkillController", "updateMain()",
function (args)
    local this = sdk.to_managed_object(args[2])
    if not this then return end
    if not this._Hunter:get_IsMaster() then
        return
    end

    StatusData.UpdateASkillController(this)
end)

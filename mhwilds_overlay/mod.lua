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

local ScreenWidth, ScreenHeight = Core.GetScreenSize()

local mod = Core.NewMod("MHWilds Overlay")
if mod.Config.ClearDataAfterQuestComplete == nil then
    mod.Config.ClearDataAfterQuestComplete = true
end

mod.Trace = {}

mod.Menu(function ()
	local configChanged = false
    local changed = false

    if not d2d then
        imgui.text_colored("reframework-d2d not found. Please install mod requirements properly.", 0xFFE0853D)
    end

    changed, mod.Config.ClearDataAfterQuestComplete = imgui.checkbox("Clear Data After Quest (if not, data persist until accept new quest)", mod.Config.ClearDataAfterQuestComplete)
    configChanged = configChanged or changed

    return configChanged
end)

return mod
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
local CONST = require("_CatLib.const")

local mod = require("mhwilds_overlay.mod")

local _M = {}

mod.OnDebugFrame(function ()
    if not mod.Config.Debug then
        return
    end

    _M.ShowTrace()
end)

function _M.ShowTrace()
    
end
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
local StatusData = require("mhwilds_overlay.status.data")
local Config = require("mhwilds_overlay.show_all_hp.conf")
local OverlayDrawHp = require("mhwilds_overlay.draw.hp")

local _M = {}

local Component_GetGameObject = Core.TypeMethod("via.Component", "get_GameObject")
local GameObject_GetTransform = Core.TypeMethod("via.GameObject", "get_Transform")
local Transform_GetPosition = Core.TypeMethod("via.Transform", "get_Position")

local NameCache = {}

local function DrawEnemyBar(conf, enemyCtx, data, screenPos, distance, simpleMode)
    local currentHP = math.ceil(data.HP)
    local maxHP = math.ceil(data.MaxHP)

    local name = NameCache[enemyCtx]
    if not name then
        name = Core.GetEnemyName(enemyCtx:get_EmID())
        NameCache[enemyCtx] = name
    end

    local x = screenPos.x
    local y = screenPos.y

    local alphaRate = 1
    if distance > Config.AlphaStartDistance then
        local ratio = (distance - Config.AlphaStartDistance) / (Config.MaxDistance - Config.AlphaStartDistance)
        alphaRate = (1-ratio) * (1-Config.MinimalAlpha) + Config.MinimalAlpha
    end
    if alphaRate <= 0 then
        return
    elseif alphaRate >= 1 then
        alphaRate = 1
    end

    if simpleMode then
        local msg = string.format("%s: %d/%d", name, currentHP, maxHP)

        if mod.Config.Debug then
            local s = {}
            if data.IsAnimal then
                s[#s+1] = "Animal"
            end
            if data.IsZako then
                s[#s+1] = "Zako"
            end
            if data.IsBoss then
                s[#s+1] = "Boss"
            end

            local color = Draw.SetAlphaRatio(Draw.ReverseRGB(conf.BackgroundColor), alphaRate)
            local alpha = ((color >> 24) & 0xFF)
            
            msg = msg .. string.format("%s %0.1f %0.1f%% 0x%x", table.concat(s, "|"), distance, alphaRate*100, alpha)
            Draw.Text(x, y, Draw.ReverseRGB(conf.FontColor), msg, conf.FontSize)
        else
            Draw.Text(x, y, Draw.SetAlphaRatio(Draw.ReverseRGB(conf.FontColor), alphaRate), msg, conf.FontSize)
        end

        local _, h = Draw.Measure(conf.FontSize, "5000中文")

        y = y + h
        local width = conf.Width
        local height = conf.Height
        Draw.Rect(x - 1, y - 1, width + 2, height + 2, Draw.SetAlphaRatio(Draw.ReverseRGB(conf.OutlineColor), alphaRate))
        Draw.Rect(x, y, width, height, Draw.SetAlphaRatio(Draw.ReverseRGB(conf.BackgroundColor), alphaRate))
        Draw.Rect(x, y, currentHP / maxHP * width, height, Draw.SetAlphaRatio(Draw.ReverseRGB(conf.Color), alphaRate))
    else
        OverlayDrawHp.DrawHpBar(conf, enemyCtx, x, y, 200, 15, false)
    end
end

local GetEnemy_ValidGameObject = Core.TypeMethod("app.EnemyCharacter", "get_ValidGameObject()")
-- local GetEnemy_ValidGameObject = Core.TypeMethod("app.EnemyCharacter", "isVisible()")
local function InitGameObjects()
    for ctx, data in pairs(OverlayData.EnemyInfo) do
        local conf
        if data.IsAnimal then
            conf = Config.Animal
        elseif data.IsZako then
            conf = Config.Zako
        elseif data.IsBoss then
            conf = Config.Boss
        else
            conf = Config.Other
        end
        if not conf.Enable then
            goto continue
        end

        if not data.HP then
            goto continue
        end
        -- if data.max <= 1000 then goto continue end
        local enemy = data.Character
        if not enemy then
            goto continue
        end
        if conf.ValidFilter and not GetEnemy_ValidGameObject:call(enemy) then -- enemy:isExtraStateNone() 
            OverlayData.EnemyInfo[ctx].Transform = nil
            OverlayData.EnemyInfo[ctx].GameObject = nil
            goto continue
        end
        if not data.Transform then
            local go = Component_GetGameObject:call(enemy)
            local transform = GameObject_GetTransform:call(go)
            OverlayData.EnemyInfo[ctx].Transform = transform
            OverlayData.EnemyInfo[ctx].GameObject = go
        end

        ::continue::
    end
end

local Vec3DistanceFunc = Core.TypeMethod("via.MathEx", "distance(via.vec3, via.vec3)")

local function DistanceBetweenPos(v1, v2)
    return (v1 - v2):length()

    -- local result = 0

    -- all perf data are under about 45-50 call count
        
    -- calc vec saves about ~0.1ms cost than calc GameObject
    -- DistanceBetweenPos(playerPos, worldPos)
    -- DistanceBetween(PlayerGameObject, go)

    -- mod.RecordCost("Vec3.Direct", function ()
    --     local x = v1.x - v2.x
    --     local y = v1.y - v2.y
    --     local z = v1.z - v2.z
    --     result = math.sqrt(x*x+y*y+z*z)
    -- end, true)

    -- ~= direct access
    -- mod.RecordCost("Vec3.REF", function ()
    --     result = (v1 - v2):length()
    -- end, true)

    -- if mod.Config.Debug then
    --     mod.RecordCost("Vec3.MathEx", function ()
    --         -- hard to believe but this got +0.03ms than direct calc
    --         result = Vec3DistanceFunc:call(nil, v1, v2)
    --     end, true)
    -- end

    -- return result
end

local function DrawAll()
    local playerPos = StatusData.HunterData.Pos
    if not playerPos then return end

    mod.InitCost("Vec3.REF")
    mod.InitCost("Vec3.Direct")
    mod.InitCost("Vec3.MathEx")
    mod.CostCompare("Vec3.MathEx", "Vec3.Direct")
    mod.CostCompare("Vec3.Direct", "Vec3.REF")

    local maxDis = Config.MaxDistance
    for ctx, data in pairs(OverlayData.EnemyInfo) do
        local conf
        if data.IsAnimal then
            conf = Config.Animal
        elseif data.IsZako then
            conf = Config.Zako
        elseif data.IsBoss then
            conf = Config.Boss
        else
            conf = Config.Other
        end
        if not conf.Enable then
            goto continue
        end
        if conf.HideDead and data.HP <= 0 then
            goto continue
        end

        local transform = data.Transform
        local go = data.GameObject
        if not transform or not go then
            goto continue
        end
        local worldPos = Transform_GetPosition:call(transform)
        local screenPos = draw.world_to_screen(worldPos)
        if not screenPos then
            goto continue
        end

        local dis = DistanceBetweenPos(playerPos, worldPos)
        if dis < maxDis then
            if Config.SimpleMode then
                DrawEnemyBar(Config, ctx, data, screenPos, dis, true)
            else
                DrawEnemyBar(conf, ctx, data, screenPos, dis, conf.SimpleMode)
            end
        end

        ::continue::
    end
end

mod.D2dRegister(function ()
end, function ()
    if not Config.Enable then
        return
    end

    if not StatusData.HunterData.Pos then
        return
    end

    OverlayDrawHp.QuestTimeLimit = Core.GetQuestTimeLimit()
    OverlayDrawHp.QuestElapsedTime = Core.GetQuestElapsedTime()

    InitGameObjects()

    DrawAll()
end, "ShowAllHp")

mod.SubDebugMenu("Show All HP", function()
    local pos = StatusData.HunterData.Pos
    if pos then
        imgui.drag_float3("LastPlayerPos", pos, 0.001)
    end
end)

return _M
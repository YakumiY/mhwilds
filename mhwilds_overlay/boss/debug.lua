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
local Draw = require("_CatLib.draw")
local CONST = require("_CatLib.const")

local MeatSlotNames = Core.GetEnumMap("app.user_data.EmParamParts.MEAT_SLOT")

---@param part app.cEmModuleParts.cDamageParts
local function InspectDamagePart(part, dmgData, title)
    if part._MeatSlot ~= 0 or dmgData.count > 0 or not (dmgData.max > 0 and dmgData.value == dmgData.max) then
        imgui.text(title)
    end
    if part._MeatSlot ~= 0 then
        imgui.text(string.format("Meat: %s", MeatSlotNames[part._MeatSlot]))
    end
    if dmgData.count > 0 then
        imgui.text(string.format("Count: %d/%d", dmgData.count, dmgData.maxCount))
    end
    if not (dmgData.max > 0 and dmgData.value == dmgData.max) then
        imgui.text(string.format("Value: %0.1f/%0.1f, min: %0.1f, def: %0.1f", dmgData.value, dmgData.max, dmgData.min, dmgData.default))
    end
end

local StateNames = Core.GetEnumMap("app.cEmModuleScar.cScarParts.STATE")
---@param scar app.cEmModuleScar.cScarParts
local function InspectScarParts(id, scar, i, scarData)
    local partIndex = scar._PartsIndex_1
    local partType = Core.GetEnemyManager():getPartsType(id, partIndex)

    imgui.text(string.format("%s [%d] State: %s,   isRide=%s, isLegend=%s", Core.GetPartTypeName(partType), i, StateNames[scar._State], tostring(scar._IsRideScar), tostring(scar._IsLegendary)))

    InspectDamagePart(scar._Normal, scarData.Normal, "NORMAL")
    InspectDamagePart(scar._Tear, scarData.Tear, "TEAR")
    InspectDamagePart(scar._Raw, scarData.Raw, "RAW")
end

local PackageHolder
local function InitPackageHolder(emId)
    
end

mod.OnDebugFrame(function ()
    imgui.push_font(Core.LoadImguiCJKFont())
    for ctx, data in pairs(EM_BreakablePartsCache) do
        imgui.text(Core.GetEnemyName(ctx:get_EmID()))
        imgui.text("Count: " .. tostring(data.Count))
        imgui.text(string.format("AllBroken: %s", tostring(data.AllBroken)))
        for index, broken in pairs(data.Broken) do
            imgui.text(string.format("%d broken: %s", index, tostring(broken)))
        end
        for index, state in pairs(data.Breakable) do
            imgui.text(string.format("%d Breakable: %s", index, tostring(state)))
        end
        for index, state in pairs(data.Severable) do
            imgui.text(string.format("%d Severable: %s", index, tostring(state)))
        end
    end
    imgui.pop_font()
end)

mod.OnDebugFrame(function ()
    local browsers = Core.GetMissionManager():getAcceptQuestTargetBrowsers()
    if browsers == nil then return end

    imgui.push_font(Core.LoadImguiCJKFont())

    local browser = browsers:get_Item(0)
    local ctx = browser:get_EmContext()
    if not ctx then return end

    imgui.text("Target: " .. tostring(Core.GetEnemyName(ctx:get_EmID())))

    local scar = ctx.Scar
    local parts = ctx.Parts

    local lostPartIds = parts._LostPartsIDs
    Core.ForEach(lostPartIds, function (partData, i) -- userdata cParts
        imgui.text("LostID: " .. tostring(partData))
    end)

    -- if enemyPartsTable[ctx] then
    --     Core.ForEach(parts._ParamParts._PartsArray._DataArray, function (partData, i) -- userdata cParts
    --         local partsType = Core.GetEnemyManager():getPartsType(ctx:get_EmID(), i)
    --         local name = CONST.EnemyPartsTypeNames[partsType]

    --         -- local instanceGuid = partData._InstanceGuid
    --         -- local index = parts:getPartsIndex(instanceGuid)._Value
    --         -- local index = parts:getLostPartsIndex(i)

    --         -- local breakParts = ctx.Parts._BreakPartsByPartsIdx
    --         -- local part = breakParts:get_Item(i)
    --         -- imgui.text(tostring(index) .. "#" .. name .. ": " .. tostring(part:get_IsLostParts()))

    --         -- local data = enemyPartsTable[ctx][i]
    --         -- local type = partData._PartsType._Value -- PARTS_TYPE_Fixed
    --         -- imgui.text(tostring(type) .. "," .. tostring(name)
    --         --     .. ": " ..  Core.FloatFixed1(data.current) .. "/" .. Core.FloatFixed1(data.max))
    --     end)
    -- end
    -- 缠蛙该数组为16，为下面二者之和 同时长度等于 _PartsEffect 的 _PartsEffectArray
    local scarData = enemyScarTable[ctx]
    local id = ctx:get_EmID()
    if scarData then
        Core.ForEach(scar._ScarParts, function (part, i)
            InspectScarParts(id, part, i, scarData[i])
        end)        
    end
    -- -- 缠蛙该数组为14
    -- Core.ForEach(scar._NormalScarParts, function (part)
    --     InspectScarParts(part)
    -- end)
    -- -- 缠蛙该数组为2
    -- Core.ForEach(scar._RideScarParts, function (part)
    --     InspectScarParts(part)
    -- end)

    imgui.pop_font()
end)

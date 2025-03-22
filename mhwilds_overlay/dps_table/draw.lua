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
local Config = require("mhwilds_overlay.dps_table.conf")

local _M = {}

local function CommonFloatText(val)
    if not val or val <= 0 then
        return "0"
    end
    return Core.FloatFixed1(val)
end

local function CommonIntText(val)
    if not val or val <= 0 then
        return "0"
    end
    return string.format("%d", math.floor(val))
end

local function PercentageText(val, max)
    if not val or val <= 0 then
        return "0"
    end
    if max <= 0 then
        max = 1
    end
    return string.format("%0.1f%%", val / max * 100)
end

local function StatusDamageText(hunter, key)
    local val = OverlayData.HunterDamageRecords[hunter][key]
    if not val or val <= 0 then
        return "0"
    end
    return CommonIntText(OverlayData.HunterDamageRecords[hunter][key])
end

local function StatusPercentageText(hunter, key)
    local val = OverlayData.HunterDamageRecords[hunter][key]
    if not val or val <= 0 then
        return "0"
    end
    return PercentageText(val, OverlayData.QuestStats[key])
end

local SupportedColumnFunc = {
    ["HR"] = function(hunter)
        local hr = OverlayData.HunterInfo[hunter].HR
        if not hr then
            return "-"
        end
        return CommonIntText(hr)
    end,
    ["Name"] = function(hunter)
        return OverlayData.HunterInfo[hunter].Name
    end,
    ["DPS"] = function(hunter)
        if not OverlayData.HunterInfo[hunter].FirstHitTime then
            return "0"
        end
        local time = (OverlayData.QuestStats.ElapsedTime - OverlayData.HunterInfo[hunter].FirstHitTime)
        if time <= 0 then
            return "0"
        end

        local dps = OverlayData.HunterDamageRecords[hunter].Total / time
        return CommonFloatText(dps)
    end,
    ["fDPS"] = function(hunter)
        if not OverlayData.HunterInfo[hunter].FirstHitTime then
            return "0"
        end
        local time = OverlayData.HunterInfo[hunter].FightingTime
        if time <= 0 then
            return "0"
        end

        local dps = OverlayData.HunterDamageRecords[hunter].Total / time
        return CommonFloatText(dps)
    end,
    ["qDPS"] = function(hunter)
        if not OverlayData.HunterInfo[hunter].FirstHitTime then
            return "0"
        end
        local time = OverlayData.QuestStats.ElapsedTime
        if time <= 0 then
            return "0"
        end

        local dps = OverlayData.HunterDamageRecords[hunter].Total / time
        return CommonFloatText(dps)
    end,
    ["Damage"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].Total)
    end,
    ["DamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Total, OverlayData.QuestStats.Total)
    end,
    ["Physical"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].Physical)
    end,
    ["PhysicalPercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Physical, OverlayData.QuestStats.Physical)
    end,
    ["SelfPhysicalPercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Physical, OverlayData.HunterDamageRecords[hunter].Total)
    end,
    ["Elemental"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].Elemental)
    end,
    ["ElementalPercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Elemental, OverlayData.QuestStats.Elemental)
    end,
    ["SelfElementalPercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Elemental, OverlayData.HunterDamageRecords[hunter].Total)
    end,
    ["FixedDamage"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].Fixed)
    end,
    ["FixedDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Fixed, OverlayData.QuestStats.Fixed)
    end,
    ["SelfFixedDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].Fixed, OverlayData.HunterDamageRecords[hunter].Total)
    end,

    ["PoisonDamage"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].PoisonDamage)
    end,
    ["PoisonDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].PoisonDamage, OverlayData.QuestStats.PoisonDamage)
    end,
    ["SelfPoisonDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].PoisonDamage, OverlayData.HunterDamageRecords[hunter].Total)
    end,
    ["BlastDamage"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].BlastDamage)
    end,
    ["BlastDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].BlastDamage, OverlayData.QuestStats.BlastDamage)
    end,
    ["SelfBlastDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].BlastDamage, OverlayData.HunterDamageRecords[hunter].Total)
    end,
    ["StabbingDamage"] = function(hunter)
        return CommonFloatText(OverlayData.HunterDamageRecords[hunter].SkillStabbingDamage)
    end,
    ["SelfStabbingDamagePercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].SkillStabbingDamage, OverlayData.HunterDamageRecords[hunter].Total)
    end,

    ["Status"] = function(hunter)
        return CommonIntText(OverlayData.HunterDamageRecords[hunter].StatusTotal)
    end,
    ["StatusPercentage"] = function(hunter)
        return PercentageText(OverlayData.HunterDamageRecords[hunter].StatusTotal, OverlayData.QuestStats.StatusTotal)
    end,
    ["FightingTime"] = function(hunter)
        return CommonFloatText(OverlayData.HunterInfo[hunter].FightingTime)
    end,
    ["HitCount"] = function(hunter)
        return CommonIntText(OverlayData.HunterInfo[hunter].HitCount)
    end,
    ["CriticalCount"] = function(hunter)
        return CommonIntText(OverlayData.HunterInfo[hunter].CriticalCount)
    end,
    ["CriticalCountPercentage"] = function(hunter)
        local criticalableHitCount = OverlayData.HunterInfo[hunter].HitCount - OverlayData.HunterInfo[hunter].NoCriticalHitCount
        return PercentageText(OverlayData.HunterInfo[hunter].CriticalCount, criticalableHitCount)
    end,
    ["NegativeCriticalCount"] = function(hunter)
        return CommonIntText(OverlayData.HunterInfo[hunter].NegCriticalCount)
    end,
    ["NegativeCriticalCountPercentage"] = function(hunter)
        local criticalableHitCount = OverlayData.HunterInfo[hunter].HitCount - OverlayData.HunterInfo[hunter].NoCriticalHitCount
        return PercentageText(OverlayData.HunterInfo[hunter].NegCriticalCount, criticalableHitCount)
    end,
    ["SoftHitCount"] = function(hunter)
        return CommonIntText(OverlayData.HunterInfo[hunter].PhysicalExploitHitCount)
    end,
    ["SoftHitCountPercentage"] = function(hunter)
        local total = OverlayData.HunterInfo[hunter].HitCount - OverlayData.HunterInfo[hunter].NoMeatHitCount
        return PercentageText(OverlayData.HunterInfo[hunter].PhysicalExploitHitCount, total)
    end,
    ["ElementalSoftHitCount"] = function(hunter)
        return CommonIntText(OverlayData.HunterInfo[hunter].ElementalExploitHitCount)
    end,
    ["ElementalSoftHitCountPercentage"] = function(hunter)
        local total = OverlayData.HunterInfo[hunter].HitCount - OverlayData.HunterInfo[hunter].NoMeatHitCount
        return PercentageText(OverlayData.HunterInfo[hunter].ElementalExploitHitCount, total)
    end,
    
    ["Stun"] = function(hunter) return StatusDamageText(hunter, "Stun"); end,
    ["Ride"] = function(hunter) return StatusDamageText(hunter, "Ride"); end,
    ["Block"] = function(hunter) return StatusDamageText(hunter, "Block"); end,
    ["Parry"] = function(hunter) return StatusDamageText(hunter, "Parry"); end,
    ["Poison"] = function(hunter) return StatusDamageText(hunter, "Poison"); end,
    ["Paralyse"] = function(hunter) return StatusDamageText(hunter, "Paralyse"); end,
    ["Sleep"] = function(hunter) return StatusDamageText(hunter, "Sleep"); end,
    ["Blast"] = function(hunter) return StatusDamageText(hunter, "Blast"); end,
    ["Stamina"] = function(hunter) return StatusDamageText(hunter, "Stamina"); end,
    ["SkillStabbing"] = function(hunter) return StatusDamageText(hunter, "SkillStabbing"); end,

    ["StunPercentage"] = function(hunter) return StatusPercentageText(hunter, "Stun"); end,
    ["RidePercentage"] = function(hunter) return StatusPercentageText(hunter, "Ride"); end,
    ["BlockPercentage"] = function(hunter) return StatusPercentageText(hunter, "Block"); end,
    ["ParryPercentage"] = function(hunter) return StatusPercentageText(hunter, "Parry"); end,
    ["PoisonPercentage"] = function(hunter) return StatusPercentageText(hunter, "Poison"); end,
    ["ParalysePercentage"] = function(hunter) return StatusPercentageText(hunter, "Paralyse"); end,
    ["SleepPercentage"] = function(hunter) return StatusPercentageText(hunter, "Sleep"); end,
    ["BlastPercentage"] = function(hunter) return StatusPercentageText(hunter, "Blast"); end,
    ["StaminaPercentage"] = function(hunter) return StatusPercentageText(hunter, "Stamina"); end,
    ["SkillStabbingPercentage"] = function(hunter) return StatusPercentageText(hunter, "SkillStabbing"); end,
    
    ["RealDamage"] = function(hunter)
        if not hunter or not hunter.get_StatusWatcher then return "0" end

        local status = hunter:get_StatusWatcher()
        if not status then return "0" end
    
        local attackHistory = status:get_AttackHistory()

        return string.format("%0.2f", attackHistory:getApplyQuestTargetDamage())
    end,
}

local ColumnCanvasRect = {
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 1000,
    Absolute = true, -- to hide relative position menu options
    UseBackground = false,
}
local ColumnWidthCache = {}

local rootCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 1000,
    Absolute = true,
    UseBackground = false,
})
local columnCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 1000,
    Absolute = true,
    UseBackground = false,
})
local lineCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 1000,
    Absolute = true, -- to hide relative position menu options
    UseBackground = false,
})
local bgCanvas = Draw.NewDivCanvas({
    Enable = true,
    OffsetX = 0,
    OffsetY = 0,
    Width = 1000,
    Height = 1000,
    UseBackground = false,
})

local DPSLineRect = {
    
}
local DPSLineRowRect = {
    
}

local function DrawStatTable()
    if mod.Runtime.StatsConfig then
        Config = mod.Runtime.StatsConfig
    end
    if OverlayData.QuestStats.ElapsedTime <= 0 then
        return
    end

    local cfg = Config
    if not cfg.Enable then return end

    local x = cfg.PosX
    local y = cfg.PosY

    local data = OverlayData.HunterInfo
    local selfHunter = Core.GetPlayerCharacter()
    local rows = 0
    if Config.HideOthers then
        if data[selfHunter] then
            rows = 1
        end
    elseif data then 
        rows = Core.GetTableSize(data)
    end

    local QuestHeight = 0
    if cfg.QuestInfo.Enable then
        QuestHeight = cfg.QuestInfo.Height

        if cfg.QuestInfo.AutoHeight then
            local _, h = Draw.Measure(cfg.QuestInfo.FontConfig, "高度")
            QuestHeight = h
        end
    end

    local TableHeaderHeight = 0
    local TableRowsHeight = 0
    if cfg.Header.Enable then
        TableHeaderHeight = cfg.Header.Height
    end
    if cfg.Row.Enable then
        TableRowsHeight = rows * cfg.Row.Height
    end
    local TableHeight = TableHeaderHeight + TableRowsHeight

    local HEIGHT = QuestHeight + TableHeight
    local WIDTH = 0

    local columns = mod.Runtime.StatTableColumns

    ---------------------------------
    -- Width and Height calculation
    ---------------------------------
    for i, columnCfg in pairs(columns) do
        if not columnCfg.Enable then
            goto continue
        end

        local width = columnCfg.Width
        if width <= 0 then
            width = cfg.Column.Width
        end
        if cfg.Column.AutoColumnWidth or columnCfg.AutoColumnWidth or cfg.Column.AutoHideZeroStatusColumns or columnCfg.AutoHideZeroStatusColumns then
            local longestMsg = ""
            local shortestMsg = ""
            local maxLen = 0
            local minLen = 999
            for hunter, data in pairs(OverlayData.HunterInfo) do
                if Config.HideOthers and not data.IsSelf then
                    goto continue1
                end
                local msg = "UNDEF"
                if SupportedColumnFunc[columnCfg.ColumnKey] then
                    msg = SupportedColumnFunc[columnCfg.ColumnKey](hunter)
                end

                local len = string.len(msg)
                if len > maxLen then
                    maxLen = len
                    longestMsg = msg
                end
                if len < minLen then
                    minLen = len
                    shortestMsg = msg
                end
                ::continue1::
            end

            if maxLen <= 0 then
                width = 0
                ColumnWidthCache[columnCfg.ColumnKey] = width
                goto continue
            end

            -- 有数据，或者不自动隐藏时，与header长度进行对比
            if (cfg.Column.AutoHideZeroStatusColumns or columnCfg.AutoHideZeroStatusColumns) and
                (longestMsg == "" or (not (longestMsg ~= "0" and shortestMsg ~= "100.0%" and maxLen > 0))) then
                width = 0
            else
                if cfg.Column.AutoColumnWidth or columnCfg.AutoColumnWidth then
                    width = Draw.Measure(columnCfg.FontConfig, ".  " .. longestMsg)

                    local headerWidth = Draw.Measure(columnCfg.FontConfig, ".  " .. columnCfg.Name)
                    if headerWidth > width then
                        width = headerWidth
                    end
                else
                    width = columnCfg.Width
                    if width <= 0 then
                        width = cfg.Column.Width
                    end
                end
            end
        end

        WIDTH = WIDTH + width
        ColumnWidthCache[columnCfg.ColumnKey] = width
        ::continue::
    end

    bgCanvas.RePos(x, y)
    bgCanvas.ReSize(WIDTH, HEIGHT)
    bgCanvas.Debug(mod.Config.Debug)
    bgCanvas.Init()
    ---------------------------------
    ---- Quest Info
    ---------------------------------
    if cfg.QuestInfo.Enable then
        local posX = x
        local posY = y
        local width = WIDTH
        local height = QuestHeight

        local msg = ""
        local limit = math.floor(OverlayData.QuestStats.LimitTime)
        if cfg.QuestInfo.QuestTime and limit >= 0 then
            local elapsed = OverlayData.QuestStats.ElapsedTime
            local elapsedMin = math.floor(elapsed / 60.0)
            local elapsedSecs = elapsed % 60.0

            local timeMsg = string.format("%02d:%02.0f/%d:00", elapsedMin, elapsedSecs, limit)
            msg = msg .. timeMsg
        end
        if cfg.QuestInfo.QuestTargets then
            if msg ~= "" then
                msg = msg .. " - "
            end

            for i, ctx in pairs(OverlayData.QuestStats.EnemyContexts) do
                if i > 1 then
                    msg = msg .. ", "
                end
                msg = msg .. Core.GetEnemyName(ctx:get_EmID())
            end
        end

        if cfg.QuestInfo.Background.Enable and cfg.QuestInfo.Background.UseBackground then
            if WIDTH <= 0 then
                local width = Draw.Measure(cfg.QuestInfo.FontConfig, msg)
                bgCanvas.ReSize(width)
            end
            cfg.QuestInfo.Background.Height = QuestHeight
            bgCanvas.Rect(cfg.QuestInfo.Background)
        else
            local nx, ny = bgCanvas.NextPos()
            bgCanvas.RePos(nx, ny+QuestHeight)
        end

        if msg ~= "" then
            Draw.SmartText(posX, posY, width, height, cfg.QuestInfo.FontConfig, msg)
        end
    end

    ---------------------------------
    -- DPS Line Pre-Calculation
    -- calculation max data of dps line
    ---------------------------------
    local allHunterTotal = 0
    local allHunterHighest = 0
    local hunterSort = {}
    if cfg.Row.Enable or cfg.DPSLine.Enable then
        -- 计算总和
        for hunter, data in pairs(OverlayData.HunterInfo) do
            if Config.HideOthers and not data.IsSelf then
                goto continue1
            end
            local total = 0
            for k, conf in pairs(cfg.DPSLine.FillKeys) do
                local val = OverlayData.HunterDamageRecords[hunter][conf.Key]
                if not val then
                    goto continue
                end
                allHunterTotal = allHunterTotal + val
                total = total + val
                ::continue::
            end
            if total > allHunterHighest then
                allHunterHighest = total
            end
            table.insert(hunterSort, {
                Hunter = hunter,
                Value = total,
            })
            ::continue1::
        end
        if cfg.Row.Sort then
            table.sort(hunterSort, function(l, r)
                return l.Value > r.Value
            end)
        end
    end

    ---------------------------------
    -- Column Header
    -- Draw columns first to calculate auto width
    ---------------------------------

    if cfg.Column.Enable then
        rootCanvas.RePos(x, y + QuestHeight)
        rootCanvas.Debug(mod.Config.Debug)
        rootCanvas.Init()

        local lastOffsetX = ColumnCanvasRect.OffsetX

        local headerH = 0
        if cfg.Header.Enable then
            headerH = cfg.Header.Height
            if cfg.Header.AutoHeight then
                _, headerH = Draw.Measure(cfg.Header.FontConfig, "H高")
            end

            if cfg.Header.Background.Enable and cfg.Header.Background.UseBackground then
                cfg.Header.Background.Height = headerH
                bgCanvas.Rect(cfg.Header.Background)
            else
                local nx, ny = bgCanvas.NextPos()
                bgCanvas.RePos(nx, ny+headerH)
            end
        end
        local rowH = cfg.Row.Height
        if cfg.Row.AutoHeight then
            _, rowH = Draw.Measure(cfg.Row.FontConfig, "H")
        end

        if cfg.Row.Enable and #hunterSort >0 then
            if cfg.Row.Background.Enable and cfg.Row.Background.UseBackground then
                cfg.Row.Background.Height = rowH* #hunterSort
                bgCanvas.Rect(cfg.Row.Background)
            else
                local nx, ny = bgCanvas.NextPos()
                bgCanvas.RePos(nx, ny+ rowH* #hunterSort)
            end
        end

        -- 渲染 DPS Line
        if cfg.DPSLine.Enable and allHunterTotal>0 then
            if cfg.DPSLine.AutoWidth then
                DPSLineRect.Width = WIDTH
            else
                DPSLineRect.Width = cfg.DPSLine.Width
            end
            if cfg.DPSLine.AutoHeight then
                DPSLineRect.Height = rowH
            else
                DPSLineRect.Height = cfg.DPSLine.Height
            end
            lineCanvas.ReSize(DPSLineRect.Width)
            
            DPSLineRowRect.Height = DPSLineRect.Height

            local dpsLineIndex = 0
            local posX = x+cfg.DPSLine.OffsetX
            local posY = y + QuestHeight + headerH
            for i = 1, #hunterSort, 1 do
                local hunter = hunterSort[i].Hunter
                if Config.HideOthers and hunter ~= selfHunter then
                    goto continue1
                end
                lineCanvas.RePos(posX, posY + dpsLineIndex * (rowH+cfg.DPSLine.OffsetY))
                lineCanvas.Debug(mod.Config.Debug)
                lineCanvas.Init()

                local hitIndex = OverlayData.HunterInfo[hunter].HitIndex
                local hitIndexStr = tostring(hitIndex)

                local hasVal = false
                for k, conf in pairs(cfg.DPSLine.FillKeys) do
                    local val = OverlayData.HunterDamageRecords[hunter][conf.Key]
                    if not val or val <= 0 then
                        goto continue
                    end
                    hasVal = true
                    local ratio = 1
                    if cfg.DPSLine.WidthAffectedByRatio then
                        if cfg.DPSLine.DPSHighestFull then
                            ratio = val / allHunterHighest
                        else
                            ratio = val / allHunterTotal
                        end
                    else
                        ratio = val / hunterSort[i].Value
                    end
                    DPSLineRowRect.Width = DPSLineRect.Width*ratio

                    if hitIndex then
                        DPSLineRowRect.BackgroundColor = conf.Colors[hitIndexStr]
                        if not DPSLineRowRect.BackgroundColor then
                            if not mod.Runtime.Colors[hitIndex] then
                                mod.Runtime.Colors[hitIndex] = Draw.RandomColor(0x44)
                            end
                            DPSLineRowRect.BackgroundColor = mod.Runtime.Colors[hitIndex]
                            -- Draw.SetAlpha(0x44, DPSLineRowRect.BackgroundColor)
                        end
                    else
                        DPSLineRowRect.BackgroundColor = conf.Colors.Others
                    end
                    
                    if mod.Config.Debug then
                        lineCanvas.Text({
                            BlockReserveX = true,
                        }, string.format("%0.1f/%0.0f", ratio, WIDTH))
                    end
                    lineCanvas.Rect(DPSLineRowRect)
                    ::continue::
                end
                
                lineCanvas.End()

                if hasVal then
                    dpsLineIndex = dpsLineIndex + 1
                end
                ::continue1::
            end
        end

        columnCanvas.RePos(x, y + QuestHeight)
        columnCanvas.Debug(mod.Config.Debug)
        for i, columnCfg in pairs(columns) do
            if not columnCfg.Enable then
                goto continue
            end

            local width = ColumnWidthCache[columnCfg.ColumnKey]

            if not width or width <= 0 then
                goto continue
            end

            columnCanvas.RePos(x+lastOffsetX, y+QuestHeight+ColumnCanvasRect.OffsetY)
            columnCanvas.Init()

            -- 渲染表头 Header
            if cfg.Header.Enable then
                columnCfg.Header.Width = width
                columnCfg.Header.Height = headerH
                columnCanvas.Rect(columnCfg.Header)
                cfg.Header.FontConfig.Width = width
                cfg.Header.FontConfig.Height = headerH
                columnCanvas.Text(cfg.Header.FontConfig, columnCfg.Name)
            end

            -- 渲染具体数据
            for i = 1, #hunterSort, 1 do
                local hunter = hunterSort[i].Hunter
                if Config.HideOthers and hunter ~= selfHunter then
                    goto continue1
                end
                columnCfg.Row.Width = width
                columnCfg.Row.Height = rowH
                columnCanvas.Rect(columnCfg.Row)

                local msg = "-"
                if SupportedColumnFunc[columnCfg.ColumnKey] then
                    msg = SupportedColumnFunc[columnCfg.ColumnKey](hunter)
                else
                    msg = "UNDEF"
                end

                cfg.Row.FontConfig.Width = width
                cfg.Row.FontConfig.Height = rowH
                columnCanvas.Text(cfg.Row.FontConfig, msg)
                ::continue1::
            end

            lastOffsetX = lastOffsetX + width
            ::continue::
        end
        columnCanvas.End()
    end

    bgCanvas.End()
end

_M.DebugRun = function ()
    local cfg = Config
    for hunter, data in pairs(OverlayData.HunterInfo) do
        for k, column in pairs(cfg.Column.Columns) do
            if not column or not column.Enable then
                goto continue
            end

            local msg = "-"
            if SupportedColumnFunc[k] then
                msg = SupportedColumnFunc[k](hunter)
            else
                msg = "NO " .. k .. " handler"
            end
            imgui.text(msg)

            ::continue::
        end
    end
end

_M.D2dRender = function ()
    DrawStatTable()
end

-- mod.OnDebugFrame(function ()
--     local cfg = Config
--     for hunter, data in pairs(OverlayData.HunterInfo) do
--         for k, column in pairs(cfg.Column.Columns) do
--             if not column or not column.Enable then
--                 goto continue
--             end

--             local msg = "-"
--             if SupportedColumnFunc[k] then
--                 msg = SupportedColumnFunc[k](hunter)
--             else
--                 msg = "NO " .. k .. " handler"
--             end
--             imgui.text(msg)

--             ::continue::
--         end
--     end
-- end)

function _M.ClearData()

end

mod.D2dRegister(function ()
    DrawStatTable()
end, "StatTable")

return _M
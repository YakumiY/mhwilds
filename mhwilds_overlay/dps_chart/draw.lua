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
local DpsChartData = require("mhwilds_overlay.dps_chart.data")

local _M = {}

local function GetHunterTotalDamage(hunter)
    if not hunter or not hunter.get_StatusWatcher then return 0 end

    local status = hunter:get_StatusWatcher()
    if not status then return 0 end

    local attackHistory = status:get_AttackHistory()

    return attackHistory:getApplyQuestTargetDamage()
end

local WeaponImages = {}

-- 上次计算的目标index
local LastHistoryCacheIndex = 0
-- 上次计算的首个index，相当于目标index-columns count
local LastHistoryCacheFirstIndex = -Config.ChartConfig.Columns

---@class HunterHistory
---@field MaxDps number
---@field Total number
---@field Dps number
---@field HunterIndex number
---@field DpsHistory table<integer, number> -- time index ->dps
---@field TotalHistory table<integer, number> -- time index ->total dmg
---@field DisplayDpsHistory number[] -- 0-120 dps
---@field DisplayTotalHistory number[] -- 0-120 total dmg

---@type HunterHistory[]
local HunterHistoryCache = {}

local InitCount = 0
local UpdateCount = 0
local OldIteration = 0
local RecycleCount = 0
local OldStart = 0
local OldEnd = 0
local ReCalcMaxDpsCount = 0

---@class SummaryData
---@field Name string
---@field IsSelf boolean
---@field Total number
---@field Ratio number
---@field Hunter Hunter
---@field HunterIndex number
---@field AttackTime number -- attacker elasped time
---@field DPS number
---@field WeaponType number -- weapon type

---@class SortedHistory
---@field IsSelf boolean
---@field MaxDPS number
---@field Index number -- Hunter Index
---@field DPS number[]
---@field Total number[]

---@class DPSComputedCache
---@field MaxDPS number
---@field MaxTotal number

-- 用于显示的缓存数据
---@type DPSComputedCache
local ComputedCache = {
    OldMaxDPS = 0,
    MaxDPS = 0,
    MaxTotal = 0,
}

---@type SortedHistory[]
local LastComputeSortedHistory = {}
---@type SummaryData[]
local LastComputeSummary = {}

--          0-119
-- 处理当前这一秒之前的所有数据：初始化（填0、继承前一秒，删去更的一个数据（若有）并更新maxDPS
local function BuildOldHistory(hunter, hunterIdx, fromIndex, toIndex)
    OldStart = fromIndex
    OldEnd = toIndex
    if not HunterHistoryCache[hunterIdx] then
        HunterHistoryCache[hunterIdx] = {
            MaxDps = 0,
            Total = 0,
            Dps = 0,
            HunterIndex = hunterIdx,
            DpsHistory = {
                Placeholder = true,
            },
            TotalHistory = {
                Placeholder = true,
            },
            DisplayDpsHistory = {},
            DisplayTotalHistory = {},
        }
    end

    local data = DpsChartData.HunterDpsRecord[hunter]

    local cache = HunterHistoryCache[hunterIdx]
    local dpsHistory = cache.DpsHistory
    local totalHistory = cache.TotalHistory
    local maxDps = cache.MaxDps

    local prevTotal = 0
    local prevInited = false
    local startIndex = LastHistoryCacheIndex
    -- 第一个采样点没有数据，需要填0或者继承
    if fromIndex < LastHistoryCacheFirstIndex or not HunterHistoryCache[hunterIdx].TotalHistory[fromIndex] then
        -- 当且仅当所需的第一个数据不存在时，初始化它。这样后续的数据即使不存在也可以基于第一个数据计算而来
        -- 如果所需的第一个数据甚至早于最早的记录，不处理，因为会填0  reqFirst -> First -> Last
        if fromIndex >= data.FirstIndex and not data.DpsHistory[fromIndex] then
            if fromIndex > data.LastIndex then
                -- 当需要的最早的数据，都晚于现在最新的数据，取最新的数据 First -> Last -> reqFirst
                prevTotal = data.DpsHistory[data.LastIndex].Total
            else
                -- 从初始点位开始，向前回溯直到找到数据 First -> reqFirst -> Last
                for i = fromIndex, data.FirstIndex-1, -1 do
                    if data.DpsHistory[i] then
                        prevTotal = data.DpsHistory[i].Total
                        break
                    end
                end
            end

            local firstDPS = 0
            local elapsedIndex = (fromIndex - data.FirstIndex) + 1
            if elapsedIndex == 1 then
                elapsedIndex = 1.5 -- grace first hit
            end

            if prevTotal > 0 and elapsedIndex > 0 then
                firstDPS = prevTotal/(elapsedIndex * Config.SampleRate)
            end
            HunterHistoryCache[hunterIdx].DpsHistory[fromIndex] = firstDPS
            HunterHistoryCache[hunterIdx].TotalHistory[fromIndex] = prevTotal
            maxDps = math.max(maxDps, firstDPS)
            prevInited = true
        end

        -- 初始化（填0 或继承）
        startIndex = fromIndex
        InitCount = InitCount + 1
    end

    if not prevInited then
        if cache.TotalHistory[startIndex-1] then
            prevTotal = cache.TotalHistory[startIndex-1]
        end
    end

    -- OldIteration = 0
    -- mod.verbose(string.format("OldIteration %d -> %d", startIndex, toIndex))
    if startIndex ~= toIndex then
        for i = startIndex, toIndex, 1 do
            OldIteration = OldIteration + 1
            local idx = i

            if idx < data.FirstIndex then
                -- 数据量不足，填充 0
                dpsHistory[idx] = 0
                totalHistory[idx] = 0
                -- mod.verbose(string.format("dps-total[%d]=%0.1f - %0.1f", idx, 0, 0))
                goto continue
            end

            local dps = 0
            local total = 0
            local snapshot = data.DpsHistory[idx]
            if snapshot then
                dps = snapshot.DPS
                total = snapshot.Total
                prevTotal = total
            else
                total = prevTotal
                local elapsedIndex = idx - data.FirstIndex + 1
                if elapsedIndex == 1 then
                    elapsedIndex = 1.5 -- grace first hit
                end

                if total > 0 and elapsedIndex > 0 then
                    dps = total/(elapsedIndex * Config.SampleRate)
                end

                -- data.DpsHistory[index - idx] = snapshot -- will crash, why?
            end

            if dps > maxDps then
                maxDps = dps
            end

            ComputedCache.OldMaxDPS = math.max(ComputedCache.OldMaxDPS, maxDps)
            dpsHistory[idx] = dps
            totalHistory[idx] = total
            -- mod.verbose(string.format("dps-total[%d]=%0.1f - %0.1f", idx, dps, total))

            prevTotal = total
            ::continue::
        end
    end
    
    HunterHistoryCache[hunterIdx].DpsHistory = dpsHistory
    HunterHistoryCache[hunterIdx].TotalHistory = totalHistory
end

-- returns dps[], total[]
---@param hunter Hunter
---@return number[], number[]
local function BuildHunterHistory(hunter, arrayIdx)
    local data = DpsChartData.HunterDpsRecord[hunter]
    if not data or not data.FirstIndex then
        return
    end
    if not OverlayData.HunterInfo[hunter] then
        return
    end

    UpdateCount = UpdateCount + 1
    local isSelf = OverlayData.HunterInfo[hunter].IsSelf
    local hunterIdx = OverlayData.HunterInfo[hunter].HitIndex

    local cols = Config.ChartConfig.Columns
    local index = DpsChartData.CurrentSampleIndex
    local reqFirstIndex = index - cols

    -- if LastHistoryCacheFirstIndex == nil then
    --     LastHistoryCacheIndex = reqFirstIndex - 1
    --     LastHistoryCacheFirstIndex = reqFirstIndex - 1
    -- end

    local isNewIndex = index > LastHistoryCacheIndex or not HunterHistoryCache[hunterIdx]

    if isNewIndex then
        BuildOldHistory(hunter, hunterIdx, reqFirstIndex, index-1)
    end
    
    local cache = HunterHistoryCache[hunterIdx]
    local dpsHistory = cache.DpsHistory
    local totalHistory = cache.TotalHistory
    local maxDps = cache.MaxDps

    -- 实时更新当前这一秒的数据
    local dps = 0
    local total = 0
    local snapshot = data.DpsHistory[index]
    if snapshot then
        dps = snapshot.DPS
        total = snapshot.Total
        -- mod.verbose(string.format("dps-total[%d]=%0.1f - %0.1f [real-time]", index, dps, total))
    else
        total = totalHistory[index-1]
        local elapsedIndex = index - data.FirstIndex + 1
        if elapsedIndex == 1 then
            elapsedIndex = 1.5 -- grace first hit
        end

        if total > 0 and elapsedIndex > 0 then
            dps = total/(elapsedIndex * Config.SampleRate)
        end
        -- mod.verbose(string.format("dps-total[%d]=%0.1f - %0.1f [old]", index, dps, total))
    end

    if dps > maxDps then
        maxDps = dps
    end

    dpsHistory[index] = dps
    totalHistory[index] = total

    local reCalcMaxDps = false
    if isNewIndex then
        local indexDiff = index - LastHistoryCacheIndex
        if indexDiff > 0 then
            for i = 1, indexDiff, 1 do
                -- gc outdated data
                local deletedDps = dpsHistory[LastHistoryCacheFirstIndex-i]
                if not deletedDps then
                    goto continue
                end
                if deletedDps >= maxDps then
                    reCalcMaxDps = true
                end
                -- dpsHistory[LastHistoryCacheFirstIndex-i] = nil
                -- totalHistory[LastHistoryCacheFirstIndex-i] = nil
                RecycleCount = RecycleCount+1
                ::continue::
            end
        end
    end
    HunterHistoryCache[hunterIdx].DpsHistory = dpsHistory
    HunterHistoryCache[hunterIdx].TotalHistory = totalHistory
    HunterHistoryCache[hunterIdx].MaxDps = maxDps
    HunterHistoryCache[hunterIdx].Total = total
    HunterHistoryCache[hunterIdx].Dps = dps

    local dpsData = cache.DisplayDpsHistory
    local totalData = cache.DisplayTotalHistory
    if isNewIndex then
        dpsData = {table.unpack(dpsHistory, reqFirstIndex, index)}
        totalData = {table.unpack(totalHistory, reqFirstIndex, index)}
    
        if reCalcMaxDps then
            ReCalcMaxDpsCount = ReCalcMaxDpsCount + 1
            maxDps = math.max(table.unpack(dpsData))
        end
    else
        dpsData[#dpsData] = dps
        totalData[#dpsData] = total
    end
    HunterHistoryCache[hunterIdx].DisplayDpsHistory = dpsData
    HunterHistoryCache[hunterIdx].DisplayTotalHistory = totalData
    HunterHistoryCache[hunterIdx].MaxDps = maxDps

    ComputedCache.MaxDPS = math.max(ComputedCache.MaxDPS, maxDps)
    ComputedCache.MaxTotal = math.max(ComputedCache.MaxTotal, total)
    if not LastComputeSortedHistory[arrayIdx] then
        LastComputeSortedHistory[arrayIdx] = {}
    end
    LastComputeSortedHistory[arrayIdx].IsSelf = isSelf
    LastComputeSortedHistory[arrayIdx].MaxDPS = maxDps
    LastComputeSortedHistory[arrayIdx].Index = hunterIdx
    LastComputeSortedHistory[arrayIdx].DPS = dpsData
    LastComputeSortedHistory[arrayIdx].Total = totalData

    --- 更新统计信息
    local attackTime = OverlayData.QuestStats.ElapsedTime - OverlayData.HunterInfo[hunter].FirstHitTime
    if attackTime < Config.SampleRate then
        attackTime = Config.SampleRate*1.5 -- grace first hit
    end

    if not LastComputeSummary[arrayIdx] then
        LastComputeSummary[arrayIdx] = {}        
    end
    
    LastComputeSummary[arrayIdx].Name = OverlayData.HunterInfo[hunter].Name
    LastComputeSummary[arrayIdx].IsSelf = OverlayData.HunterInfo[hunter].IsSelf
    LastComputeSummary[arrayIdx].Hunter = hunter
    LastComputeSummary[arrayIdx].HunterIndex = hunterIdx
    LastComputeSummary[arrayIdx].Total = total
    LastComputeSummary[arrayIdx].Ratio = total / OverlayData.QuestStats.Total
    LastComputeSummary[arrayIdx].AttackTime = attackTime
    LastComputeSummary[arrayIdx].DPS = total / attackTime
    LastComputeSummary[arrayIdx].WeaponType = OverlayData.HunterInfo[hunter].WeaponType
end

local function BuildDpsChartData()
    local index = DpsChartData.CurrentSampleIndex
    if index == 0 and DpsChartData.LastBuildCacheIndex == -1 then
        return
    end

    if index <= DpsChartData.LastBuildCacheIndex then
        return
    end
    index = index -1

    local cols = Config.ChartConfig.Columns
    local reqFirstIndex = index - cols

    ComputedCache.MaxDPS = 0 -- ComputedCache.OldMaxDPS
    ComputedCache.MaxTotal = 0
    -- LastComputeSortedHistory = {}
    -- LastComputeSummary = {}
    -- hunter:get_StableQuestMemberIndex()
    -- get_StableMemberIndex() and get_StableQuestMemberIndex() return -1 in NPC, wtf
    local arrayIdx = 1
    for hunter, data in pairs(DpsChartData.HunterDpsRecord) do
        if not OverlayData.HunterInfo[hunter] or not OverlayData.HunterInfo[hunter].IsPlayer then
            goto continue
        end
        BuildHunterHistory(hunter, arrayIdx)

        -- GCOutdatedData(hunter)
        arrayIdx = arrayIdx + 1
        ::continue::
    end
    LastHistoryCacheIndex = index
    LastHistoryCacheFirstIndex = reqFirstIndex


    table.sort(LastComputeSortedHistory, function (left, right)
        return left.MaxDPS > right.MaxDPS
    end)

    table.sort(LastComputeSummary, function (left, right)
        return left.Total > right.Total
    end)

    -- do no update current sec
    DpsChartData.LastBuildCacheIndex = index
end

local AutoThresholdArrayBig = {50000, 20000, 10000, 5000, 2000, 1000, 500, 200}
local AutoThresholdArray = {100, 50, 20, 10, 5}

local DpsLabelConfig = {
    Threshold = {
        threshold = function (max)
            max = max * 0.8 -- we don't want the chart be filled
            if Config.ChartConfig.ChartTypeTotalDamage or Config.ChartConfig.AutoDpsMeter then
                if max > 200 then
                    for _, threshold in pairs(AutoThresholdArrayBig) do
                        if max > threshold then
                            return threshold
                        end
                    end
                end

                for _, threshold in pairs(AutoThresholdArray) do
                    if max > threshold then
                        return threshold
                    end
                end
                return 2.5
            else
                return Config.ChartConfig.DpsMeterInterval
            end
        end,
        format = function (num)
            if Config.ChartConfig.ChartTypeTotalDamage then
                return string.format("%0.0f", num)
            else
                return string.format("%0.1f/s", num)
            end
        end,
    },
    SampleRate = {
        format = function (i)
            local delta = 0
            if DpsChartData.CurrentSampleIndex then
                delta = DpsChartData.CurrentSampleIndex - Config.ChartConfig.Columns
            end
            i = i + delta
            local curSecs = i * Config.SampleRate
            local min = math.floor(curSecs / 60)
            local secs = math.floor(curSecs % 60)
            return string.format("%d:%02.0f", min, secs)
        end,
        show = function (i)
            local delta = 0
            if DpsChartData.CurrentSampleIndex then
                delta = DpsChartData.CurrentSampleIndex - Config.ChartConfig.Columns
            end
            i = i + delta
            local curSecs = i * Config.SampleRate
            return curSecs > 0 and curSecs % Config.ChartConfig.QuestTimeInterval == 0
        end
    }
}

local LastDataArr = nil

local ImPlotStyleVar_FillAlpha = 4
mod.OnDebugFrame(function ()
    if not LastDataArr or not implot then
        return
    end

    local implot = implot
    
    imgui.begin_window("DPS Chart")

    if implot.begin_plot("DPS") then
        implot.setup_axes("time","DPS");
    

        implot.push_style_var(ImPlotStyleVar_FillAlpha, 0.4)
        for idx = 1, #LastDataArr, 1 do
            local ys = LastDataArr[idx]

            local xs = {}
            for i = 1, #ys do
                xs[i] = i
            end
            implot.plot_shaded(string.format("%d", idx), xs, ys);
        end

        implot.end_plot()
    end


    imgui.end_window()
end)

local function DrawDpsChart()
    if not Config.Enable then return end

    if not (Config.ChartConfig.Enable or Config.QuestInfoConfig.Enable or Config.PlayerInfoConfig.Enable) then
        return
    end

    local summary = LastComputeSummary
    if not summary or #summary == 0 then
        return
    end

    -- if mod.Config.Debug and summary[1] then
    --     if not summary[2] then
    --         summary[2] = summary[1]
    --     end
    --     if not summary[3] then
    --         summary[3] = summary[1]
    --     end
    --     if not summary[4] then
    --         summary[4] = summary[1]
    --     end
    -- end

    local bgColor = Config.BackgroundColor
    local x = Config.PosX
    local y = Config.PosY

    local thresholdFmt = DpsLabelConfig.Threshold.format
    local sampleRateFmt = DpsLabelConfig.SampleRate.format
    -------------------------------
    -- [calculate background width]
    -- Width: PADDING(Left) + Vertical Label MaxWidth + LabelMargin +
    --          ThresholdExtend + DPS Chart Width + Max(ThresholdExtend, Horizontal Label MaxWidth) + PADDING(Right)
    -- [calculate background height]
    -- height: PADDING(Top) + Vertical Label MaxHeight/2 +
    --              DPS Chart Height +
    --        Max(Vertical Label MaxHeight/2, Horizontal Label MaxHeight) +PADDING(Top)
    -------------------------------
    local maxDisp = 100.1
    if Config.ChartConfig.ChartTypeTotalDamage then
        maxDisp = 50000
    end
    local VerticalLabelMaxWidth, VerticalLabelMaxHeight = Draw.Measure(Config.ChartConfig.DpsMeterFontConfig, thresholdFmt(maxDisp))
    local HorizontalLabelMaxWidth, HorizontalLabelMaxHeight = Draw.Measure(Config.ChartConfig.TimeMeterFontConfig, sampleRateFmt(40*60.0))

    -- 仅曲线部分 h/w
    local DpsCurveHeight = Config.ChartConfig.Height
    local DpsCurveWidth = Config.ChartConfig.ColumnWidth * Config.ChartConfig.Columns


    local DpsLabelPaddingLeft = 0 -- 时间标记导致的 DPS 标尺向左延长
    if Config.ChartConfig.EnableDpsMeter or Config.ChartConfig.EnableQuestTimeMeter then
        DpsLabelPaddingLeft = HorizontalLabelMaxWidth / 2
    end

    local DpsLabelPaddingRight = 0
    if Config.ChartConfig.EnableDpsMeter then
        DpsLabelPaddingRight = math.floor(HorizontalLabelMaxWidth / 2)
    end

    local DpsLabelWidth = 0
    if Config.ChartConfig.EnableDpsMeter then
        DpsLabelWidth = VerticalLabelMaxWidth + Config.ChartConfig.DpsMeterPadding
    end
    local DpsLabelHeight = 0
    local DpsLabelHeightTop = 0
    local DpsLabelHeightDown = 0
    if Config.ChartConfig.EnableDpsMeter then
        DpsLabelHeightTop = math.floor(VerticalLabelMaxHeight/2)
        DpsLabelHeightDown = DpsLabelHeightTop
        DpsLabelHeight = DpsLabelHeightTop + DpsLabelHeightDown
    end
    if Config.ChartConfig.EnableQuestTimeMeter then
        DpsLabelHeightDown = math.max(DpsLabelHeightTop, HorizontalLabelMaxHeight)
        DpsLabelHeight = DpsLabelHeightTop + DpsLabelHeightDown
    end

    local DpsWidth = Config.ChartConfig.PaddingLeft + DpsLabelWidth + DpsLabelPaddingLeft + DpsCurveWidth + DpsLabelPaddingRight + Config.ChartConfig.PaddingRight
    local DpsHeight = Config.ChartConfig.PaddingTop + DpsLabelHeight + DpsCurveHeight + Config.ChartConfig.PaddingDown

    -------------------------------
    -- SUMMARY Calculation
    -------------------------------
    local enableQuestInfo = Config.QuestInfoConfig.Enable and Core.IsActiveQuest()
    local QuestHeight = 0
    if enableQuestInfo then
        QuestHeight = Config.QuestInfoConfig.Height + Config.QuestInfoConfig.OffsetY
    end

    local SummaryHeight = 0
    if Config.PlayerInfoConfig.Enable then
        local rows = 0
        if Config.HideOthers then
            for _, data in pairs(summary) do
                if data.IsSelf then
                    rows = 1
                    break
                end
            end
        else
            rows = #summary
        end
        SummaryHeight = rows * Config.PlayerInfoConfig.Height + Config.PlayerInfoConfig.OffsetY
    end

    local WIDTH = math.max(Config.MinWidth, DpsWidth)
    local HEIGHT = QuestHeight + SummaryHeight + DpsHeight

    local QuestYStart = y + Config.QuestInfoConfig.OffsetY
    local SummaryYStart = y + QuestHeight + Config.PlayerInfoConfig.OffsetY
    local DpsYStart = y + QuestHeight + SummaryHeight + Config.ChartConfig.OffsetY

    -------------------------------
    -- Background
    -------------------------------
    if bgColor then
        local bgX = x
        local bgY = y
        local bgWidth = WIDTH
        local bgHeight = 0
        if Config.ChartConfig.Enable then
            bgHeight = bgHeight + DpsHeight
        end
        if Config.QuestInfoConfig.Enable then
            bgHeight = bgHeight + QuestHeight
        end
        if Config.PlayerInfoConfig.Enable then
            bgHeight = bgHeight + SummaryHeight
        end

        Draw.Rect(bgX, bgY, bgWidth, bgHeight, bgColor)
    end

    -------------------------------
    -- SUMMARY
    -------------------------------
    -- Quest Data
    if enableQuestInfo then
        local posX = x + Config.QuestInfoConfig.OffsetX
        local posY = QuestYStart
        local width = WIDTH
        local height = Config.QuestInfoConfig.Height

        local elapsed = OverlayData.QuestStats.ElapsedTime
        local elapsedMin = math.floor(elapsed / 60.0)
        local elapsedSecs = elapsed % 60.0
        local limit = math.floor(OverlayData.QuestStats.LimitTime)

        local timeMsg = string.format("%02d:%02.0f/%d:00", elapsedMin, elapsedSecs, limit)

        Draw.SmartText(posX, posY, width, height, Config.QuestInfoConfig.QuestTime, timeMsg)
    end

    -- PlayerData
    if Config.PlayerInfoConfig.Enable then
        local highestDPS = 0
        if Config.PlayerInfoConfig.HighestDPSLineFill then
            for i, data in pairs(summary) do
                if data.DPS > highestDPS then
                    highestDPS = data.DPS
                end
            end
        end
        local countedI = 0
        for i, data in pairs(summary) do -- i from 1
            if Config.HideOthers and not data.IsSelf then
                goto continue1
            end
            countedI = countedI + 1
            local posX = x + Config.PlayerInfoConfig.OffsetX + Config.PlayerInfoConfig.PaddingLeft
            local posY = SummaryYStart + (countedI-1)*Config.PlayerInfoConfig.Height
            local width = WIDTH - Config.PlayerInfoConfig.OffsetX - Config.PlayerInfoConfig.PaddingLeft
            local height = Config.PlayerInfoConfig.Height
            local endY = posY + height

            local color = mod.Runtime.Colors[data.HunterIndex]
            local solidColor = mod.Runtime.SolidColors[data.HunterIndex]
            if not color then
                color = Draw.RandomColor(0x44)
                mod.Runtime.Colors[data.HunterIndex] = color
            end
            if not solidColor then
                solidColor = Draw.SetAlpha(color, 0xAA)
                mod.Runtime.SolidColors[data.HunterIndex] = solidColor
            end
            local dpsWidth = width
            if Config.PlayerInfoConfig.HighestDPSLineFill and highestDPS > 0 then
                dpsWidth = width * (data.DPS / highestDPS)
            else
                dpsWidth = width * data.Ratio
            end

            if Config.PlayerInfoConfig.ShowDPSLineBackground then
                Draw.DimmedRect(posX, endY, dpsWidth, Config.PlayerInfoConfig.Height, color)
            end
            if Config.PlayerInfoConfig.ShowDPSLine then
                local thickness = Config.PlayerInfoConfig.DPSLineHeight
                local yOffset = math.floor(thickness/2)
                Draw.Line(posX, endY - yOffset, posX + dpsWidth, endY - yOffset, thickness, solidColor)
            end

            -- weapon icon
            local weaponIconOffsetX
            local imgY
            if Config.PlayerInfoConfig.ShowWeaponIcon then
                local size = Config.PlayerInfoConfig.WeaponIconSize
                imgY = posY + Config.PlayerInfoConfig.WeaponIconOffsetY
                if size < height then
                    imgY = imgY + math.floor((height-size)/2)
                end
                
                weaponIconOffsetX = Config.PlayerInfoConfig.WeaponIconOffsetX
                if size < Config.PlayerInfoConfig.DataOffsetX then
                    weaponIconOffsetX = weaponIconOffsetX + math.floor((Config.PlayerInfoConfig.DataOffsetX-size)/2)
                end
                local imgX = posX + weaponIconOffsetX

                if WeaponImages[data.WeaponType] then
                    Draw.Image(WeaponImages[data.WeaponType], imgX, imgY, size, size)
                end
            end

            -- HR
            if OverlayData.HunterInfo[data.Hunter] and OverlayData.HunterInfo[data.Hunter].HR ~= nil then
                local hrMsg = tostring(OverlayData.HunterInfo[data.Hunter].HR)
                -- if mod.Config.Debug then
                --     hrMsg = "999"
                -- end
                local offsetX = 0
                local hrY = posY
                if Config.PlayerInfoConfig.ShowWeaponIcon and Config.PlayerInfoConfig.HRLabelAlignWithWeaponIcon then
                    offsetX = weaponIconOffsetX
                    local w, h = Draw.Measure(Config.PlayerInfoConfig.HR, hrMsg)
                    offsetX = offsetX + math.floor((Config.PlayerInfoConfig.WeaponIconSize-w)/2)
                    hrY = imgY-h
                end
                Draw.SmartText(posX+offsetX, hrY, width, height, Config.PlayerInfoConfig.HR, hrMsg)
            end

            posX = posX + Config.PlayerInfoConfig.DataOffsetX
            local textWidth = width - Config.PlayerInfoConfig.DataOffsetX - Config.PlayerInfoConfig.PaddingRight
            local name = data.Name
            if mod.Config.Debug then
                name = name .. "#" .. tostring(i-1)
            end
            Draw.SmartText(posX, posY, textWidth, height, Config.PlayerInfoConfig.Name, name)

            local dpsMsg = string.format("%0.1f/s", data.DPS)
            Draw.SmartText(posX, posY, textWidth, height, Config.PlayerInfoConfig.DPS, dpsMsg)

            local totalMsg = tostring(math.floor(data.Total))
            Draw.SmartText(posX, posY, textWidth, height, Config.PlayerInfoConfig.TotalDamage, totalMsg)

            local ratio = string.format("%0.1f%%", data.Ratio * 100)
            Draw.SmartText(posX, posY, textWidth, height, Config.PlayerInfoConfig.Percentage, ratio)

            ::continue1::
        end
    end

    -------------------------------
    -- DPS Chart
    -------------------------------
    if Config.ChartConfig.Enable then
        local colW = Config.ChartConfig.ColumnWidth
        local len = Config.ChartConfig.Columns

        local posX = x + Config.ChartConfig.OffsetX + Config.ChartConfig.PaddingLeft
        local posY = DpsYStart + Config.ChartConfig.PaddingTop

        local max = ComputedCache.MaxDPS
        if Config.ChartConfig.ChartTypeTotalDamage then
            max = ComputedCache.MaxTotal
        end
        -------------------------------
        -- vertical labels (dps) (100.0/s)
        -------------------------------
        if Config.ChartConfig.EnableDpsMeter then
            local threshold = DpsLabelConfig.Threshold.threshold(max)
            local levels = math.max(math.floor(max / threshold), 1) + 1
            max = levels * threshold
            if len > 1 then
                local dpsLabelXStart = posX
                local dpsMeterX = dpsLabelXStart + DpsLabelWidth
                local dpsMeterXEnd = dpsMeterX + DpsLabelPaddingLeft + DpsCurveWidth + DpsLabelPaddingRight
                local dpsMeterY = posY + DpsLabelHeightTop

                for i = 0, levels, 1 do
                    local ratio = i * threshold / max
                    local offsetY = math.floor((1 - ratio) * DpsCurveHeight)
                    local label = thresholdFmt(i * threshold)
                    local labelWidth = Draw.Measure(Config.ChartConfig.DpsMeterFontConfig, label)

                    local labelX = posX + (VerticalLabelMaxWidth - labelWidth)
                    local labelY = posY + offsetY
                    Draw.TextWithConfig(labelX, labelY, label, Config.ChartConfig.DpsMeterFontConfig)

                    local meterY = dpsMeterY + offsetY
                    Draw.Line(dpsMeterX, meterY, dpsMeterXEnd, meterY, 1, 0xFFFFFFFF)
                end
            end
        end

        -------------------------------
        -- horizontal labels (7:00) quest time
        -------------------------------
        local dpsCurveX = posX + DpsLabelWidth + DpsLabelPaddingLeft
        local dpsCurveY = posY + DpsLabelHeightTop + DpsCurveHeight

        if Config.ChartConfig.EnableQuestTimeMeter then
            if len > 2 then
                local meterYTop = posY + DpsLabelHeightTop
                if Config.ChartConfig.TimeMeterHeight >= 0 then
                    meterYTop = dpsCurveY - Config.ChartConfig.TimeMeterHeight
                end
                -- we don't want left or right close line
                for i = 1, len-1, 1 do
                    if DpsLabelConfig.SampleRate.show(i) then
                        local label = sampleRateFmt(i)
                        local labelWidth, _ = Draw.Measure(Config.ChartConfig.TimeMeterFontConfig, label)
                        local labelX = dpsCurveX + colW * i

                        Draw.TextWithConfig(labelX - labelWidth / 2, dpsCurveY, label, Config.ChartConfig.TimeMeterFontConfig)
                        Draw.Line(labelX, meterYTop, labelX, dpsCurveY, 1, 0xFFFFFFFF)
                    end
                end
            end
        end

        if Config.ChartConfig.ChartTypeTotalDamage then
            local dataArr = {}
            local colors = {}
            local solidColors = {}
            for i=1, #LastComputeSortedHistory, 1 do
                local data = LastComputeSortedHistory[i]
                if Config.HideOthers and not data.IsSelf then
                    goto continue1
                end
                table.insert(dataArr, data.Total)
                table.insert(colors, mod.Runtime.Colors[data.Index])
                table.insert(solidColors, mod.Runtime.SolidColors[data.Index])
                ::continue1::
            end

            LastDataArr = dataArr
            Draw.FilledLinePlots(dpsCurveX, dpsCurveY, DpsCurveHeight, Config.ChartConfig.ColumnWidth, colors, solidColors, dataArr, max, Config.ChartConfig.Fill)
        else
            local dataArr = {}
            local colors = {}
            local solidColors = {}
            for i=1, #LastComputeSortedHistory, 1 do
                local data = LastComputeSortedHistory[i]
                if Config.HideOthers and not data.IsSelf then
                    goto continue1
                end
                table.insert(dataArr, data.DPS)
                table.insert(colors, mod.Runtime.Colors[data.Index])
                table.insert(solidColors, mod.Runtime.SolidColors[data.Index])
                ::continue1::
            end

            LastDataArr = dataArr
            Draw.FilledLinePlots(dpsCurveX, dpsCurveY, DpsCurveHeight, Config.ChartConfig.ColumnWidth, colors, solidColors, dataArr, max, Config.ChartConfig.Fill)
        end
    end
end

local LastBuildTime = 0
mod.OnUpdateBehavior(function()
    -- 不要放到d2d reg里执行，否则会有bug
    if OverlayData.QuestStats.ElapsedTime - LastBuildTime > 0.1 then
        if OverlayData.IsInTraningArea or Core.IsActiveQuest() then
            BuildDpsChartData()
        end
        LastBuildTime = OverlayData.QuestStats.ElapsedTime
    end
end)

mod.D2dRegister(function ()
    Draw.LoadFont(Config.PlayerInfoConfig.HR)
    Draw.LoadFont(Config.PlayerInfoConfig.Name)
    Draw.LoadFont(Config.PlayerInfoConfig.DPS)
    Draw.LoadFont(Config.PlayerInfoConfig.TotalDamage)
    Draw.LoadFont(Config.PlayerInfoConfig.Percentage)
    Draw.LoadFont(Config.QuestInfoConfig.QuestTime)
    Draw.LoadFont(Config.ChartConfig.DpsMeterFontConfig)
    Draw.LoadFont(Config.ChartConfig.TimeMeterFontConfig)

    if Config.PlayerInfoConfig.ShowWeaponIcon then
        WeaponImages[CONST.WeaponType.GreatSword] = mod.LoadImage("greatsword.png")
        WeaponImages[CONST.WeaponType.SwordShield] = mod.LoadImage("swordshield.png")
        WeaponImages[CONST.WeaponType.DualBlades] = mod.LoadImage("dualblades.png")
        WeaponImages[CONST.WeaponType.LongSword] = mod.LoadImage("longsword.png")
        WeaponImages[CONST.WeaponType.Hammer] = mod.LoadImage("hammer.png")
        WeaponImages[CONST.WeaponType.HuntingHorn] = mod.LoadImage("huntinghorn.png")
        WeaponImages[CONST.WeaponType.Lance] = mod.LoadImage("lance.png")
        WeaponImages[CONST.WeaponType.Gunlance] = mod.LoadImage("gunlance.png")
        WeaponImages[CONST.WeaponType.SwitchAxe] = mod.LoadImage("switchaxe.png")
        WeaponImages[CONST.WeaponType.ChargeBlade] = mod.LoadImage("chargeblade.png")
        WeaponImages[CONST.WeaponType.InsectGlaive] = mod.LoadImage("insectglaive.png")
        WeaponImages[CONST.WeaponType.Bow] = mod.LoadImage("bow.png")
        WeaponImages[CONST.WeaponType.HeavyBowgun] = mod.LoadImage("heavybowgun.png")
        WeaponImages[CONST.WeaponType.LightBowgun] = mod.LoadImage("lightbowgun.png")
    end
end, function ()
    if mod.Runtime.DpsConfig then
        Config = mod.Runtime.DpsConfig
    end
    DrawDpsChart()
end, "DpsChart")

function _M.ClearData()
    LastHistoryCacheIndex = 0
    LastHistoryCacheFirstIndex = -Config.ChartConfig.Columns

    HunterHistoryCache = {}
    InitCount = 0
    UpdateCount = 0
    OldIteration = 0
    RecycleCount = 0
    OldStart = 0
    OldEnd = 0
    ReCalcMaxDpsCount = 0
    ComputedCache = {
        OldMaxDPS = 0,
        MaxDPS = 0,
        MaxTotal = 0,
    }

    LastComputeSortedHistory = {}
    LastComputeSummary = {}

    LastBuildTime = 0
end

mod.OnDebugFrame(function ()
    local hunter = Core.GetPlayerCharacter()
    if not hunter then return end

    imgui.text(string.format("RecycleCount: %d, OldIteration: %d (%d->%d), InitCount: %d, UpdateCount: %d, ReCalcMaxDpsCount: %d",
        RecycleCount, OldIteration, OldStart, OldEnd, InitCount, UpdateCount, ReCalcMaxDpsCount))
    if false and OverlayData.HunterInfo[hunter] then
        -- debug internal data
        local curIdx = DpsChartData.CurrentSampleIndex
        local firstIdx = DpsChartData.CurrentSampleIndex - Config.ChartConfig.Columns
        local hunterIdx = OverlayData.HunterInfo[hunter].HitIndex

        -- BuildHunterHistory(hunter)
        imgui.text(string.format("%d -> %d [Request]", firstIdx, curIdx))
        imgui.text(string.format("%d -> %d [Cached]", LastHistoryCacheFirstIndex, LastHistoryCacheIndex))
        local data = HunterHistoryCache[hunterIdx]
        if data then
            local maxDPS = data.MaxDps
            local dpsData = {table.unpack(data.DpsHistory, firstIdx, curIdx)}
            local totalData = {table.unpack(data.TotalHistory, firstIdx, curIdx)}
            
            imgui.text("data: " .. tostring(data))
            imgui.text("maxDPS: " .. tostring(maxDPS))
            imgui.text("DpsHistory: " .. tostring(data.DpsHistory) .. ", size: " .. tostring(Core.GetTableSize(data.DpsHistory)))
            imgui.text("TotalHistory: " .. tostring(data.TotalHistory) .. ", size: " .. tostring(Core.GetTableSize(data.TotalHistory)))
            imgui.text("dpsData: " .. tostring(dpsData))
            imgui.text("totalData: " .. tostring(totalData))
        end
    end
    if OverlayData.HunterInfo[hunter] then
        -- debug computed data
        local current = DpsChartData.CurrentSampleIndex 
        local firstIdx = DpsChartData.CurrentSampleIndex - Config.ChartConfig.Columns
        local hunterIdx = OverlayData.HunterInfo[hunter].HitIndex
        
        imgui.text("Time: " .. tostring(OverlayData.QuestStats.ElapsedTime))
        imgui.text(string.format("%d  [Current]", current))
        imgui.text(string.format("%d -> %d [Request]", firstIdx, current))
        imgui.text(string.format("%d -> %d [Cached]", LastHistoryCacheFirstIndex or -1, LastHistoryCacheIndex or -1))
        imgui.text(string.format("%d[%d]", Core.GetTableSize(HunterHistoryCache), hunterIdx))
        -- BuildHunterHistory(hunter)
        local data = HunterHistoryCache[hunterIdx]
        if data then
            imgui.text("== Cached History Data ==")
            imgui.text("data: " .. tostring(data))
            imgui.text("maxDPS: " .. tostring(data.MaxDps))
            imgui.text("DPS: " .. tostring(data.Dps))
            imgui.text("Total: " .. tostring(data.Total))
            imgui.text("hunterIdx: " .. tostring(data.HunterIndex))
            imgui.text("DpsHistory: " .. tostring(data.DpsHistory) .. ", size: " .. tostring(Core.GetTableSize(data.DpsHistory)))
            -- Debug.DebugTable(data.DpsHistory)
            imgui.text("TotalHistory: " .. tostring(data.TotalHistory) .. ", size: " .. tostring(Core.GetTableSize(data.TotalHistory)))

            local dpsData = data.DpsHistory
            local totalData = data.TotalHistory

            if dpsData[current] then
                local msg = "("
                local dpsMsg = "("
                local totalMsg = "("
                for i = firstIdx, current, 1 do
                    local idx = tostring(i)
                    local dps = Core.FloatFixed1(dpsData[i])
                    local total = Core.FloatFixed1(totalData[i])
                    local max = math.max(string.len(idx), string.len(dps)-1, string.len(total)-1)

                    msg = msg .. "." .. string.rep("0", max-string.len(idx)) .. idx .. ", "
                    dpsMsg = dpsMsg .. string.rep("0", max-string.len(dps)+1) .. dps .. ", "
                    totalMsg = totalMsg .. string.rep("0", max-string.len(total)+1) .. total .. ", "
                end

                imgui.text(msg .. ")")
                imgui.text(dpsMsg .. ")")
                imgui.text(totalMsg .. ")")
            end
            
        else
            imgui.text("ERROR: nil cache")
        end

        local history = LastComputeSortedHistory[1]
        if history then
            local maxDPS = history.MaxDPS
            local dpsData = history.DPS
            local totalData = history.Total
            
            imgui.text("== Sorted Data ==")
            imgui.text("maxDPS: " .. tostring(maxDPS))
            imgui.text("dpsData: " .. tostring(dpsData) .. ", size: " .. tostring(#(dpsData)))
            imgui.text("totalData: " .. tostring(totalData) .. ", size: " .. tostring(#(dpsData)))
            
            local dpsData = LastComputeSortedHistory[1].DPS
            local totalData = LastComputeSortedHistory[1].Total

            local dpsMsg = "("
            local totalMsg = "("
            for i = 1, #dpsData, 1 do
                local dps = Core.FloatFixed1(dpsData[i])
                local total = Core.FloatFixed1(totalData[i])
                dpsMsg = dpsMsg .. dps .. ", "
                totalMsg = totalMsg .. total .. ", "
            end

            imgui.text(dpsMsg .. ")")
            imgui.text(totalMsg .. ")")
        else
            imgui.text("ERROR: nil sorted history")
        end

        local summary = LastComputeSummary[1]
        if summary then
            for i = 1, #LastComputeSummary, 1 do
                summary = LastComputeSummary[i]
                imgui.text("maxDPS: " .. tostring(summary.Name))
                imgui.text("HunterIndex: " .. tostring(summary.HunterIndex))
                imgui.text("WeaponType: " .. tostring(summary.WeaponType))
            end
        else
            imgui.text("ERROR: nil sorted history")
        end
    end


    imgui.text("QuestMemberIndex: " .. tostring(hunter:get_StableQuestMemberIndex()))

    if OverlayData.HunterDamageRecords[hunter] then
        Debug.DebugTable(OverlayData.HunterDamageRecords[hunter])
    end

    imgui.text("MemberCount: " .. tostring(#LastComputeSortedHistory))

end)

return _M
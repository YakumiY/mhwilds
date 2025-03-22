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

local LibConf = require("_CatLib.config")
local Scale = LibConf.UIScale

local mod = require("mhwilds_overlay.mod")

local ScreenWidth, ScreenHeight = Core.GetScreenSize()

local Config = mod.Config.DpsChartConfig

local function SetColors(Config)
    mod.Runtime.Colors[0] = Draw.ReverseRGB(Config.P1Color)
    mod.Runtime.Colors[1] = Draw.ReverseRGB(Config.P2Color)
    mod.Runtime.Colors[2] = Draw.ReverseRGB(Config.P3Color)
    mod.Runtime.Colors[3] = Draw.ReverseRGB(Config.P4Color)
    mod.Runtime.Colors.Bg = Draw.ReverseRGB(Config.BackgroundColor)

    mod.Runtime.SolidColors[0] = Draw.ReverseRGB(Config.P1SolidColor)
    mod.Runtime.SolidColors[1] = Draw.ReverseRGB(Config.P2SolidColor)
    mod.Runtime.SolidColors[2] = Draw.ReverseRGB(Config.P3SolidColor)
    mod.Runtime.SolidColors[3] = Draw.ReverseRGB(Config.P4SolidColor)
end

local function InitConfig(Config)
    Scale = LibConf.UIScale

    if Config == nil then
        Config = {}
        mod.Config.DpsChartConfig = Config
    end

    if Config.PosX == nil then
        Config.PosX = 0
        Config.PosY = (ScreenHeight or 2160)*0.6

        Config.MinWidth = 0
    end

    if Config.SampleRate == nil then
        Config.SampleRate = 1
    end

    if Config.PlayerInfoConfig == nil then
        Config.PlayerInfoConfig = {
            Enable = true,
            Height = 60 *Scale,
            OffsetX = 0,
            OffsetY = 8 *Scale,

            PaddingLeft = 0,
            PaddingRight = 10 *Scale,

            ShowWeaponIcon = true,
            WeaponIconSize = 32 *Scale,
            WeaponIconOffsetX = 0,
            WeaponIconOffsetY = 6,
            HRLabelAlignWithWeaponIcon = true,

            ShowDPSLine = true,
            DPSLineHeight = 4 *Scale,
            ShowDPSLineBackground = true,
            HighestDPSLineFill = false,

            DataOffsetX = 48 *Scale,
            HR = {
                FontSize = 14 *Scale,
                OffsetY = 4 *Scale,
            },
            Name = {
                VerticalCenter = true,
                FontSize = 24 *Scale,
                Bold = true,
            },
            DPS = {
                HorizontalCenter = true,
                FontSize = 22 *Scale,
                Bold = true,
                OffsetY = 4 *Scale,
            },
            TotalDamage = {
                HorizontalCenter = true,
                FontSize = 16 *Scale,
                OffsetY = 30 *Scale,
            },
            Percentage = {
                RightAlign = true,
                VerticalCenter = true,
                FontSize = 24 *Scale,
                Bold = true,
            },
        }
    end

    if Config.QuestInfoConfig == nil then
        Config.QuestInfoConfig = {
            Enable = true,
            Height = 32 *Scale,

            OffsetX = 48 *Scale,
            OffsetY = 8 *Scale,

            QuestTime = {
                VerticalCenter = true,
                FontSize = 24 *Scale,
            },
        }
    end

    if Config.ChartConfig == nil then
        Config.ChartConfig = {
            Enable = true,
            Fill = true,
            Height = 200 *Scale,

            OffsetX = 0,
            OffsetY = 0,

            PaddingLeft = 10 *Scale,
            PaddingRight = 10 *Scale,
            PaddingTop = 16 *Scale,
            PaddingDown = 4 *Scale,

            Columns = 120,
            ColumnWidth = math.ceil(3 *Scale),

            ChartTypeTotalDamage = false,

            EnableDpsMeter = true,
            AutoDpsMeter = true,
            DpsMeterPadding = 12 *Scale,
            DpsMeterInterval = 50 *Scale,
            DpsMeterFontConfig = {
                FontSize = 16 *Scale,
            },

            EnableQuestTimeMeter = true,
            QuestTimeInterval = 30,
            TimeMeterHeight = -1 *Scale,
            TimeMeterFontConfig = {
                FontSize = 16 *Scale,
            }
        }
    end
    if Config.ChartConfig.ChartTypeTotalDamage == nil then
        Config.ChartConfig.ChartTypeTotalDamage = false
    end

    if Config.Enable == nil then
        Config.Enable = (Config.ChartConfig.Enable or Config.QuestInfoConfig.Enable or Config.PlayerInfoConfig.Enable)
    end
    if Config.HideOthers == nil then
        Config.HideOthers = false
    end

    if Config.BackgroundColor == nil then
        Config.BackgroundColor = 0x90000000
        Config.P1Color = Draw.ReverseRGB(0x4400FF00)
        Config.P2Color = Draw.ReverseRGB(0x44FF0000)
        Config.P3Color = Draw.ReverseRGB(0x44FFFF00)
        Config.P4Color = Draw.ReverseRGB(0x4400FFFF)
        Config.P1SolidColor = Draw.ReverseRGB(0xAA00FF00)
        Config.P2SolidColor = Draw.ReverseRGB(0xAAFF0000)
        Config.P3SolidColor = Draw.ReverseRGB(0xAAFFFF00)
        Config.P4SolidColor = Draw.ReverseRGB(0xAA00FFFF)
    end

    mod.Runtime.Colors = {
        [0] = Draw.ReverseRGB(Config.P1Color),
        [1] = Draw.ReverseRGB(Config.P2Color),
        [2] = Draw.ReverseRGB(Config.P3Color),
        [3] = Draw.ReverseRGB(Config.P4Color),
        Bg = Draw.ReverseRGB(Config.BackgroundColor),
    }
    mod.Runtime.SolidColors = {
        [0] = Draw.ReverseRGB(Config.P1SolidColor),
        [1] = Draw.ReverseRGB(Config.P2SolidColor),
        [2] = Draw.ReverseRGB(Config.P3SolidColor),
        [3] = Draw.ReverseRGB(Config.P4SolidColor),
    }
    SetColors(Config)
    mod.Runtime.DpsConfig = Config

    return Config
end

Config = InitConfig(Config)

local ScreenWidth, ScreenHeight = Core.GetScreenSize()

local w, h = ScreenWidth, ScreenHeight

mod.SubMenu("DPS Chart Options", function ()
	local configChanged = false
    local changed = false

    if imgui.button("Regenerate Config") then
        Config = InitConfig()
    end
    
    changed, Config.Enable = imgui.checkbox("Enable", Config.Enable)
    configChanged = configChanged or changed

    changed, Config.HideOthers = imgui.checkbox("HideOthers", Config.HideOthers)
    configChanged = configChanged or changed
    
    changed, Config.PosX = imgui.slider_int("Pos X", Config.PosX, 0, w)
    configChanged = configChanged or changed
    changed, Config.PosY = imgui.slider_int("Pos Y", Config.PosY, 0, h)
    configChanged = configChanged or changed
    changed, Config.MinWidth = imgui.slider_int("Min. Width", Config.MinWidth, 0, w)
    configChanged = configChanged or changed

    imgui.text("Sample rate, change value will clear data")
    changed, Config.SampleRate = imgui.drag_float("SampleRate (seconds)", Config.SampleRate, 0.1, 0.2, 10)
    configChanged = configChanged or changed

    if imgui.tree_node("Quest Info") then
        changed, Config.QuestInfoConfig.Enable = imgui.checkbox("Enable", Config.QuestInfoConfig.Enable)
        configChanged = configChanged or changed

        changed, Config.QuestInfoConfig.Height = imgui.slider_int("Height", Config.QuestInfoConfig.Height, 10, 500)
        configChanged = configChanged or changed

        changed, Config.QuestInfoConfig.OffsetX = imgui.drag_int("OffsetX", Config.QuestInfoConfig.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.QuestInfoConfig.OffsetY = imgui.drag_int("OffsetY", Config.QuestInfoConfig.OffsetY, 1, -h, h)
        configChanged = configChanged or changed

        changed, Config.QuestInfoConfig.QuestTime = Draw.FontConfigMenu(Config.QuestInfoConfig.QuestTime, "Quest Time Font Config")
        configChanged = configChanged or changed

        imgui.tree_pop()
    end

    if imgui.tree_node("Player Info & Chart") then
        changed, Config.PlayerInfoConfig.Enable = imgui.checkbox("Enable", Config.PlayerInfoConfig.Enable)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.Height = imgui.slider_int("Height", Config.PlayerInfoConfig.Height, 10, 500)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.OffsetX = imgui.drag_int("OffsetX", Config.PlayerInfoConfig.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.PlayerInfoConfig.OffsetY = imgui.drag_int("OffsetY", Config.PlayerInfoConfig.OffsetY, 1, -h, h)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.PaddingLeft = imgui.drag_int("PaddingLeft", Config.PlayerInfoConfig.PaddingLeft, 1, -w, w)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.PaddingRight = imgui.drag_int("PaddingRight", Config.PlayerInfoConfig.PaddingRight, 1, -w, w)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.DataOffsetX = imgui.drag_int("Data OffsetX", Config.PlayerInfoConfig.DataOffsetX, 1, -w, w)
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.ShowWeaponIcon = imgui.checkbox("Show Weapon Icon", Config.PlayerInfoConfig.ShowWeaponIcon)
        configChanged = configChanged or changed
        if Config.PlayerInfoConfig.ShowWeaponIcon then
            changed, Config.PlayerInfoConfig.HRLabelAlignWithWeaponIcon = imgui.checkbox("Align HR Label in Weapon Icon", Config.PlayerInfoConfig.HRLabelAlignWithWeaponIcon)
            configChanged = configChanged or changed

            changed, Config.PlayerInfoConfig.WeaponIconSize = imgui.slider_int("Weapon Icon Size", Config.PlayerInfoConfig.WeaponIconSize, 10, 320)
            configChanged = configChanged or changed

            changed, Config.PlayerInfoConfig.WeaponIconOffsetX = imgui.drag_int("Weapon Icon OffsetX", Config.PlayerInfoConfig.WeaponIconOffsetX, 1, -w, w)
            configChanged = configChanged or changed
            changed, Config.PlayerInfoConfig.WeaponIconOffsetY = imgui.drag_int("Weapon Icon OffsetY", Config.PlayerInfoConfig.WeaponIconOffsetY, 1, -h, h)
            configChanged = configChanged or changed
        end

        if imgui.tree_node("DPS Line Config") then
            changed, Config.PlayerInfoConfig.ShowDPSLine = imgui.checkbox("Show DPS Line", Config.PlayerInfoConfig.ShowDPSLine)
            configChanged = configChanged or changed

            changed, Config.PlayerInfoConfig.DPSLineHeight = imgui.slider_int("DPS Line Height", Config.PlayerInfoConfig.DPSLineHeight, 1, Config.PlayerInfoConfig.Height)
            configChanged = configChanged or changed

            changed, Config.PlayerInfoConfig.ShowDPSLineBackground = imgui.checkbox("Show DPS Line Background", Config.PlayerInfoConfig.ShowDPSLineBackground)
            configChanged = configChanged or changed

            changed, Config.PlayerInfoConfig.HighestDPSLineFill = imgui.checkbox("Highest DPS Fill the Line", Config.PlayerInfoConfig.HighestDPSLineFill)
            configChanged = configChanged or changed

            imgui.tree_pop()
        end

        changed, Config.PlayerInfoConfig.HR = Draw.FontConfigMenu(Config.PlayerInfoConfig.HR, "HR/MR Font Config")
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.Name = Draw.FontConfigMenu(Config.PlayerInfoConfig.Name, "Name Font Config")
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.DPS = Draw.FontConfigMenu(Config.PlayerInfoConfig.DPS, "DPS Font Config")
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.TotalDamage = Draw.FontConfigMenu(Config.PlayerInfoConfig.TotalDamage, "TotalDamage Font Config")
        configChanged = configChanged or changed

        changed, Config.PlayerInfoConfig.Percentage = Draw.FontConfigMenu(Config.PlayerInfoConfig.Percentage, "Percentage Font Config")
        configChanged = configChanged or changed

        imgui.tree_pop()
    end

    if imgui.tree_node("DPS Graph") then
        changed, Config.ChartConfig.Enable = imgui.checkbox("Enable", Config.ChartConfig.Enable)
        configChanged = configChanged or changed

        changed, Config.ChartConfig.ChartTypeTotalDamage = imgui.checkbox("Show Total Damage instead of DPS", Config.ChartConfig.ChartTypeTotalDamage)
        configChanged = configChanged or changed

        changed, Config.ChartConfig.Height = imgui.slider_int("Height", Config.ChartConfig.Height, 10, 500)
        configChanged = configChanged or changed

        changed, Config.ChartConfig.OffsetX = imgui.drag_int("OffsetX", Config.ChartConfig.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.ChartConfig.OffsetY = imgui.drag_int("OffsetY", Config.ChartConfig.OffsetY, 1, -h, h)
        configChanged = configChanged or changed

        changed, Config.ChartConfig.PaddingLeft = imgui.drag_int("PaddingLeft", Config.ChartConfig.PaddingLeft, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.ChartConfig.PaddingRight = imgui.drag_int("PaddingRight", Config.ChartConfig.PaddingRight, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.ChartConfig.PaddingTop = imgui.drag_int("PaddingTop", Config.ChartConfig.PaddingTop, 1, -h, h)
        configChanged = configChanged or changed
        changed, Config.ChartConfig.PaddingDown = imgui.drag_int("PaddingDown", Config.ChartConfig.PaddingDown, 1, -h, h)
        configChanged = configChanged or changed

        if imgui.tree_node("DPS Meter") then
            changed, Config.ChartConfig.EnableDpsMeter = imgui.checkbox("Enable", Config.ChartConfig.EnableDpsMeter)
            configChanged = configChanged or changed
            if Config.ChartConfig.EnableDpsMeter then
                changed, Config.ChartConfig.Fill = imgui.checkbox("Fill", Config.ChartConfig.Fill)
                configChanged = configChanged or changed

                changed, Config.ChartConfig.DpsMeterPadding = imgui.slider_int("Padding", Config.ChartConfig.DpsMeterPadding, 0, 120)
                configChanged = configChanged or changed

                changed, Config.ChartConfig.ColumnWidth = imgui.slider_int("Column Width", Config.ChartConfig.ColumnWidth, 1, 10)
                configChanged = configChanged or changed
                changed, Config.ChartConfig.Columns = imgui.slider_int("Columns", Config.ChartConfig.Columns, 10, 240)
                configChanged = configChanged or changed

                changed, Config.ChartConfig.AutoDpsMeter = imgui.checkbox("Auto DPS Meter", Config.ChartConfig.AutoDpsMeter)
                configChanged = configChanged or changed

                if not Config.ChartConfig.AutoDpsMeter then
                    changed, Config.ChartConfig.DpsMeterInterval = imgui.slider_int("DPS Meter Interval", Config.ChartConfig.DpsMeterInterval, 1, 100)
                    configChanged = configChanged or changed
                end

                changed, Config.ChartConfig.DpsMeterFontConfig = Draw.FontConfigMenu(Config.ChartConfig.DpsMeterFontConfig, "DPS Meter Label Font Config", true)
                configChanged = configChanged or changed
            end

            imgui.tree_pop()
        end

        if imgui.tree_node("Quest Time Meter") then
            changed, Config.ChartConfig.EnableQuestTimeMeter = imgui.checkbox("Enable", Config.ChartConfig.EnableQuestTimeMeter)
            configChanged = configChanged or changed
            if Config.ChartConfig.EnableQuestTimeMeter then
                changed, Config.ChartConfig.QuestTimeInterval = imgui.slider_int("Quest Time Interval", Config.ChartConfig.QuestTimeInterval, 10, 120)
                configChanged = configChanged or changed

                changed, Config.ChartConfig.TimeMeterHeight = imgui.slider_int("Quest Time Meter Height (-1 = full)", Config.ChartConfig.TimeMeterHeight, -1, 400)
                configChanged = configChanged or changed

                changed, Config.ChartConfig.TimeMeterFontConfig = Draw.FontConfigMenu(Config.ChartConfig.TimeMeterFontConfig, "Quest Time Label Font Config", true)
                configChanged = configChanged or changed
            end
        end

        imgui.tree_pop()
    end

    if imgui.tree_node("Player Colors") then
        changed, Config.BackgroundColor = imgui.color_picker("Background Color", Config.BackgroundColor)
        configChanged = configChanged or changed
        changed, Config.P1Color = imgui.color_picker("Player Color", Config.P1Color)
        configChanged = configChanged or changed
        changed, Config.P1SolidColor = imgui.color_picker("Player Solid Color", Config.P1SolidColor)
        configChanged = configChanged or changed
        changed, Config.P2Color = imgui.color_picker("P2 Color", Config.P2Color)
        configChanged = configChanged or changed
        changed, Config.P2SolidColor = imgui.color_picker("P2 Solid Color", Config.P2SolidColor)
        configChanged = configChanged or changed
        changed, Config.P3Color = imgui.color_picker("P3 Color", Config.P3Color)
        configChanged = configChanged or changed
        changed, Config.P3SolidColor = imgui.color_picker("P3 Solid Color", Config.P3SolidColor)
        configChanged = configChanged or changed
        changed, Config.P4Color = imgui.color_picker("P4 Color", Config.P4Color)
        configChanged = configChanged or changed
        changed, Config.P4SolidColor = imgui.color_picker("P4 Solid Color", Config.P4SolidColor)
        configChanged = configChanged or changed

        if configChanged then
            SetColors(Config)
        end
    end
    return configChanged
end)

return Config
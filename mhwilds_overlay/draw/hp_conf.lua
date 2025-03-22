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
local Utils = require("_CatLib.utils")

local LibConf = require("_CatLib.config")
local Scale = LibConf.UIScale

local mod = require("mhwilds_overlay.mod")

local ScreenWidth, ScreenHeight = Core.GetScreenSize()
local DefaultWidth = ScreenWidth*0.15

local _M = {}

---@class HpWidgetHeader
---@field Enable boolean
---@field OffsetX number
---@field OffsetY number
---@field MarginX number
---@field PaddingX number
---@field Width number
---@field Height number
---@field ShowCurrentHpValues boolean
---@field ShowMaxHpValues boolean
---@field ShowSmallIcon boolean
---@field ShowCrownIcon boolean
---@field AutoCrownIconSize boolean
---@field CrownIconSize number
---@field ShowWeaknessIcon boolean
---@field AutoWeaknessIconSize boolean
---@field ShowWeaknessDetail boolean
---@field WeaknessIconSize number
---@field Name FontConfig
---@field HP FontConfig
---@field Action FontConfig|nil
---@field QuestTime FontConfig|nil

---@class HpWidgetRedHp
---@field Enable boolean
---@field DelayTime number
---@field FadeTime number
---@field Color number

---@class HpWidgetHpSegementIndicator
---@field Enable boolean
---@field OffsetX number
---@field OffsetY number
---@field UseCircleShape boolean
---@field Circle CircleConfig
---@field Rect RectConfig
---@field HideDrainIndicator boolean

---@class HpWidgetHpSegement
---@field Enable boolean
---@field Indicator HpWidgetHpSegementIndicator
---@field UseSegHpValueInBar boolean
---@field UseSegHpValueInText boolean
---@field UsePercentageSegment boolean
---@field SegmentPercentage number
---@field Colors number[]

---@class HpWidgetTheme
---@field Enable boolean
---@field Header HpWidgetHeader
---@field RedHp HpWidgetRedHp|nil
---@field Hp RectConfig
---@field HpSegement HpWidgetHpSegement|nil
---@field Stamina RectConfig|nil
---@field Angry RectConfig|nil

---@return HpWidgetTheme
function _M.NewDefaultTheme()
    Scale = LibConf.UIScale
    local theme = {
        Enable = true,
        Header = {
            Enable = true,
            OffsetX = 0,
            OffsetY = 4 *Scale,
            MarginX = 0,
            PaddingX = 4 *Scale,
            Width = DefaultWidth *Scale,
            Height = 28 *Scale,

            ShowHPRatio = false,
            ShowCurrentHpValues = true,
            ShowMaxHpValues = true,
            ShowSmallIcon = false,
            ShowCrownIcon = true,
            AutoCrownIconSize = true,
            CrownIconSize = 24 *Scale,
            ShowWeaknessIcon = true,
            AutoWeaknessIconSize = true,
            ShowWeaknessDetail = false,
            WeaknessIconSize = 24 *Scale,

            ---@type FontConfig
            Name = {
                Enable = true,
                Absolute = true,
                VerticalCenter = true,
            },
            ---@type FontConfig
            HP = {
                Enable = true,
                Absolute = true,
                VerticalCenter = true,
            },
            ---@type FontConfig
            Action = {
                Enable = true,
                Absolute = true,
                VerticalCenter = true,
            },
            ---@type FontConfig
            QuestTime = {
                Enable = true,
                Absolute = true,
                VerticalCenter = true,
                RightAlign = true,
            },
        },
        
        RedHp = {
            Enable = true,
            DelayTime = 2.5,
            FadeTime = 1.5,
            Color = Draw.ReverseRGB(0xFFAE0D11),
        },
        Hp = {
            Enable = true,
            Absolute = true,
            IsFillRect = true,
            OffsetX = 0,
            OffsetY = 0,
            Width = DefaultWidth *Scale,
            Height = 24 *Scale,
            -- Color = Draw.ReverseRGB(0xFFA7695A),
            Color = Draw.ReverseRGB(0xFF76DCA7), -- 崛起血条颜色
            UseBackground = true,
            BackgroundColor = 0x90000000, --Draw.ReverseRGB(0xFF39201B),
            BlockRenderX = false,
            BlockRenderY = true,
        },

        HpSegement = {
            Enable = false,    
            Indicator = {
                Enable = true,
                OffsetX = 0,
                OffsetY = 8 *Scale,
                UseCircleShape = true,
                ---@type CircleConfig
                Circle = {
                    Radius = 10 *Scale,
                    Color = Draw.ReverseRGB(0xFF76DCA7), -- 崛起血条颜色
                    IsFill = true,
                    IsRing = false,
                    RingWidth = 4 *Scale,
                    UseBackground = true,
                    BackgroundColor = 0x90000000,
                    OutlineThickness = 1,
                    OutlineColor = 0xFF000000,
                    Clockwise = false,
                    Absolute = true,
                    PaddingX = 4 *Scale,
                },
                ---@type RectConfig
                Rect = {
                    Width = 14 *Scale,
                    Height = 18 *Scale,
                    ParallelogramOffsetX = -6 *Scale,
                    Color = Draw.ReverseRGB(0xFF76DCA7), -- 崛起血条颜色
                    IsFillRect = true,
                    UseBackground = true,
                    BackgroundColor = 0x90000000,
                    OutlineThickness = 1,
                    OutlineColor = 0xFF000000,
                    Absolute = true,
                    PaddingX = 4 *Scale,
                },

                HideDrainIndicator = true,
            },
            UseSegHpValueInBar = true,
            UseSegHpValueInText = false,
            UsePercentageSegment = false,
            SegmentPercentage = 10,
            SegmentValue = 2000,

            -- TODO
            MaxSegmentCount = 10, -- 超过这个数量会叠加颜色
            SegmentSeparator = 5,
            Colors = {
                Draw.ReverseRGB(0x4400FF00),
                Draw.ReverseRGB(0x44FF0000),
                Draw.ReverseRGB(0x44FFFF00),
                Draw.ReverseRGB(0x4400FFFF),
                Draw.ReverseRGB(0x44FF00FF),
            },
        },

        ---@type RectConfig
        Stamina = {
            Enable = true,
            OffsetX = 0,
            OffsetY = 0,
            Width = DefaultWidth *Scale,
            Height = 8 *Scale,
            Absolute = true,
            -- Color = Draw.ReverseRGB(0xFF1A4C66),
            Color = Draw.ReverseRGB(0xFFF3D35F), -- Draw.ReverseRGB(0xFF5FD3F3), --
            UseBackground = true,
            BackgroundColor = 0x90000000,
            BlockRenderX = false,
            BlockRenderY = true,
            IsFillRect = true,
            
            Label = {
                ShowCurrent = false,
                ShowMax = false,
                ShowRatio = false,
                ShowTimer = false,
            },
        },
        ---@type RectConfig
        Angry = {
            Enable = true,
            OffsetX = 0,
            OffsetY = 0,
            Width = DefaultWidth *Scale,
            Height = 8 *Scale,
            Absolute = true,
            Color = Draw.ReverseRGB(0xFF98001B),
            UseBackground = true,
            BackgroundColor = 0x90000000,
            BlockRenderX = false,
            BlockRenderY = true,
            IsFillRect = true,
            
            Label = {
                ShowCurrent = false,
                ShowMax = false,
                ShowRatio = false,
                ShowTimer = false,
            },
        },
    }

    return theme
end

local w, h = ScreenWidth, ScreenHeight

---@param theme HpWidgetTheme
function _M.ThemeMenu(tag, theme, func)
	local configChanged = false
    local changed = false

    if imgui.tree_node(tag) then
        changed, theme.Enable = imgui.checkbox("Enable", theme.Enable)
        configChanged = configChanged or changed

        if func then
            func()
        end

        if imgui.tree_node("Header") then
            changed, theme.Header.Enable = imgui.checkbox("Enable", theme.Header.Enable)
            configChanged = configChanged or changed
            changed, theme.Header.OffsetX = imgui.drag_int("OffsetX", theme.Header.OffsetX, 1, -w, w)
            configChanged = configChanged or changed
            changed, theme.Header.OffsetY = imgui.drag_int("OffsetY", theme.Header.OffsetY, 1, -h, h)
            configChanged = configChanged or changed
            changed, theme.Header.PaddingX = imgui.drag_int("PaddingX", theme.Header.PaddingX, 1, -w, w)
            configChanged = configChanged or changed
            
            changed, theme.Header.ShowSmallIcon = imgui.checkbox("Show Small Icon", theme.Header.ShowSmallIcon)
            configChanged = configChanged or changed
            changed, theme.Header.Name = Draw.FontConfigMenu(theme.Header.Name, "Name Text")
            configChanged = configChanged or changed
            changed, theme.Header.ShowCrownIcon = imgui.checkbox("Show Crown Icon", theme.Header.ShowCrownIcon)
            configChanged = configChanged or changed
            changed, theme.Header.AutoCrownIconSize = imgui.checkbox("Auto Crown Icon Size", theme.Header.AutoCrownIconSize)
            configChanged = configChanged or changed
            if not theme.Header.AutoCrownIconSize then
                changed, theme.Header.CrownIconSize = imgui.drag_int("Crown Icon Size", theme.Header.CrownIconSize, 1, 1, 60)
                configChanged = configChanged or changed
            end

            changed, theme.Header.HP = Draw.FontConfigMenu(theme.Header.HP, "HP Text")
            configChanged = configChanged or changed

            changed, theme.Header.ShowHPRatio = imgui.checkbox("Show HP Ratio", theme.Header.ShowHPRatio)
            configChanged = configChanged or changed
            if not theme.Header.ShowHPRatio  then
                changed, theme.Header.ShowCurrentHpValues = imgui.checkbox("Show Current HP", theme.Header.ShowCurrentHpValues)
                configChanged = configChanged or changed
                changed, theme.Header.ShowMaxHpValues = imgui.checkbox("Show Max HP", theme.Header.ShowMaxHpValues)
                configChanged = configChanged or changed
            end

            changed, theme.Header.ShowWeaknessIcon = imgui.checkbox("Show Weakness Icon", theme.Header.ShowWeaknessIcon)
            configChanged = configChanged or changed
            changed, theme.Header.AutoWeaknessIconSize = imgui.checkbox("Auto Weakness Icon Size", theme.Header.AutoWeaknessIconSize)
            configChanged = configChanged or changed
            if not theme.Header.AutoWeaknessIconSize then
                changed, theme.Header.WeaknessIconSize = imgui.drag_int("Weakness Icon Size", theme.Header.WeaknessIconSize, 1, 1, 60)
                configChanged = configChanged or changed
            end
            changed, theme.Header.ShowWeaknessDetail = imgui.checkbox("Show Weakness Detail Number", theme.Header.ShowWeaknessDetail)
            configChanged = configChanged or changed
            
            if theme.Header.Action then
                changed, theme.Header.Action = Draw.FontConfigMenu(theme.Header.Action, "Current Action Text")
                configChanged = configChanged or changed
            end

            if theme.Header.QuestTime then
                changed, theme.Header.QuestTime = Draw.FontConfigMenu(theme.Header.QuestTime, "QuestTime Text")
                configChanged = configChanged or changed
            end
    
            imgui.tree_pop()
        end

        changed, theme.Hp = Draw.RectConfigMenu(theme.Hp, "Hp Bar")
        configChanged = configChanged or changed

        if theme.RedHp then
            changed, theme.RedHp.Enable = imgui.checkbox("Boss Red HP Enable", theme.RedHp.Enable)
            configChanged = configChanged or changed
            if theme.RedHp.Enable then
                if imgui.tree_node("Red Hp Options") then
                    changed, theme.RedHp.DelayTime = imgui.drag_float("Delay Time", theme.RedHp.DelayTime, 0.1, 0.1, 100)
                    configChanged = configChanged or changed
                    changed, theme.RedHp.FadeTime = imgui.drag_float("Fade Time", theme.RedHp.FadeTime, 0.1, 0.1, 100)
                    configChanged = configChanged or changed
                    changed, theme.RedHp.Color = imgui.color_picker("Color", theme.RedHp.Color)
                    configChanged = configChanged or changed
                    imgui.tree_pop()
                end
            end
        end

        if theme.Stamina then
            changed, theme.Stamina = Draw.RectConfigMenu(theme.Stamina, "Stamina Bar")
            configChanged = configChanged or changed
        end

        if theme.Angry then
            changed, theme.Angry = Draw.RectConfigMenu(theme.Angry, "Angry Bar")
            configChanged = configChanged or changed
        end

        if theme.HpSegement then
            changed, theme.HpSegement.Enable = imgui.checkbox("Hp Bar Segmented Mode", theme.HpSegement.Enable)
            configChanged = configChanged or changed

            if theme.HpSegement.Enable then
                if imgui.tree_node("Seg Mode Options") then
                    local segConf = theme.HpSegement

                    changed, segConf.UseSegHpValueInBar = imgui.checkbox("Use Seg HP in Bar", segConf.UseSegHpValueInBar)
                    configChanged = configChanged or changed

                    changed, segConf.UseSegHpValueInText = imgui.checkbox("Use Seg HP in Text", segConf.UseSegHpValueInText)
                    configChanged = configChanged or changed

                    changed, segConf.Indicator.HideDrainIndicator = imgui.checkbox("Hide Drain Indicator", segConf.Indicator.HideDrainIndicator)
                    configChanged = configChanged or changed

                    changed, segConf.UsePercentageSegment = imgui.checkbox("Use Percentage", segConf.UsePercentageSegment)
                    configChanged = configChanged or changed
                    
                    if segConf.UsePercentageSegment then
                        changed, segConf.SegmentPercentage = imgui.slider_int("Seg Percentage", segConf.SegmentPercentage, 1, 100)
                        configChanged = configChanged or changed
                    else
                        changed, segConf.SegmentValue = imgui.drag_int("Seg Value", segConf.SegmentValue, 100, 200, 10000)
                        configChanged = configChanged or changed
                    end
                    
                    if imgui.tree_node("Indicator Options") then
                        changed, segConf.Indicator.UseCircleShape = imgui.checkbox("Use Circle Shape Indicator", segConf.Indicator.UseCircleShape)
                        configChanged = configChanged or changed

                        changed, segConf.Indicator.OffsetX = imgui.drag_int("OffsetX", segConf.Indicator.OffsetX, 1, -w, w)
                        configChanged = configChanged or changed
                        changed, segConf.Indicator.OffsetY = imgui.drag_int("OffsetY", segConf.Indicator.OffsetY, 1, -h, h)
                        configChanged = configChanged or changed

                        if segConf.Indicator.UseCircleShape then
                            changed, theme.HpSegement.Indicator.Circle = Draw.CircleConfigMenu(theme.HpSegement.Indicator.Circle, "Circle Seg Indicator Options")
                            configChanged = configChanged or changed
                        else
                            changed, theme.HpSegement.Indicator.Rect = Draw.RectConfigMenu(theme.HpSegement.Indicator.Rect, "Rect Seg Indicator Options")
                            configChanged = configChanged or changed
                        end
                        imgui.tree_pop()
                    end


                    if configChanged then
                        theme.HpSegement = segConf
                    end

                    imgui.tree_pop()
                end
            end
        end

        imgui.tree_pop();
    end

    return configChanged, theme
end

return _M
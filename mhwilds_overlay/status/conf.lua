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
local Imgui = require("_CatLib.imgui")

local LibConf = require("_CatLib.config")
local Scale = LibConf.UIScale

local mod = require("mhwilds_overlay.mod")

local ScreenWidth, ScreenHeight = Core.GetScreenSize()
local w, h = ScreenWidth, ScreenHeight

---@class OverlayStatusConfig
---@field Enable boolean
---@field HunterConfig OverlayStatusHunterConfig
---@field BuffWidgetConfig OverlayStatusBuffWidgetConfig

---@class OverlayStatusBuffWidgetConfig
---@field Enable boolean
---@field MergeAllBuffs boolean
---@field OffsetX number -- Merge All Buffs PosX
---@field OffsetY number -- Merge All Buffs PosY
---@field Columns number
---@field SkillConfig OverlayStatusGroupConfig
---@field MusicSkillConfig OverlayStatusGroupConfig
---@field OtomoSkillConfig OverlayStatusGroupConfig
---@field ItemBuffConfig OverlayStatusGroupConfig
---@field ASkillConfig OverlayStatusGroupConfig
---@field WeaponConfig OverlayStatusGroupConfig

---@type OverlayStatusConfig
local Config = mod.Config.StatusConfig

---@return FontConfig
local function NewDefaultFontStyle()
    return {
        Enable = true,
        OffsetY = 0,
        FontSize = 16 *Scale,
        Color = 0xFFFFFFFF,
        BlockRenderX = true,
        BlockReserveX = true,
        BlockRenderY = false,
    }
end

---@return CircleConfig
local function NewBuffRingConfig()
    return {
        Enable = true,
        OffsetY = 0,
        Absolute = true,
        IsFill = true,
        IsRing = true,
        Radius = 18 *Scale,
        RingWidth = 4 *Scale,
        UseBackground = true,
        BackgroundColor = 0x90000000,
        RingUseCircleBackground = true,
        RingAutoCircleBackgroundRadius = true,
        OutlineThickness = 0,
        Clockwise = false,
        PaddingX = 4 *Scale,
        PaddingY = 4 *Scale,
        BlockRenderX = true,
        BlockRenderY = true,
        BlockReserveY = true,
    }
end
---@class OverlayStatusSkillStatusConfig
---@field Enable boolean
---@field DisplayName string
---@field Text FontConfig
---@field Circle CircleConfig

---@return OverlayStatusSkillStatusConfig
local function NewDefaultSkillConfig(key, name)
    local conf = {
        Enable = true,
        DisplayName = name or key,
        Text = NewDefaultFontStyle(),
        Circle = NewBuffRingConfig(),
    }
    if conf.DisplayName == nil or conf.DisplayName == "" then
        conf.DisplayName = tostring(key)
    end
    return conf
end

---@class OverlayStatusHunterStaminaConfig
---@field Enable boolean
---@field Segmented boolean
---@field SegmentValue number
---@field SegmentRingMargin number
---@field SegmentRingWidth number
---@field AutoHide boolean
---@field DisappearDelay number
---@field ShowUsedStamina boolean
---@field UsedStaminaColor number
---@field RelativePosition boolean
---@field WorldOffsetX number
---@field WorldOffsetY number
---@field WorldOffsetZ number
---@field RelativeOffsetX number
---@field RelativeOffsetY number
---@field FixedOffsetX number
---@field FixedOffsetY number
---@field StaminaCircle CircleConfig
---@field EnableColorTransition boolean
---@field TransitionToColor number
---@field ThresholdRatio number
---@field ThresholdValue number
---@field ThresholdColor number
---@field InsectStaminaCircle CircleConfig
---@field InsectStaminaCircleCenterPlayer boolean
---@field InsectEnableColorTransition boolean
---@field InsectTransitionToColor number
---@field InsectThresholdRatio number
---@field InsectThresholdValue number
---@field InsectThresholdColor number

---@class OverlayStatusHunterConfig
---@field Stamina OverlayStatusHunterStaminaConfig

---@return CircleConfig
local function NewStaminaRingConfig()
    return {
        Enable = true,
        OffsetY = 0,
        Absolute = true,
        IsFill = true,
        IsRing = true,
        Radius = 44 *Scale,
        RingWidth = 24 *Scale,
        Color = Draw.ReverseRGB(0xFF65D84D), -- Draw.ReverseRGB(0xFF76B295), -- Draw.ReverseRGB(0xFF8EB116),
        BackgroundRatio = 1,
        UseBackground = true,
        BackgroundColor = Draw.ReverseRGB(0x90000000),
        RingUseCircleBackground = false,
        RingAutoCircleBackgroundRadius = true,
        IsFillOutline = true,
        OutlineThickness = 0,
        OutlineColor = Draw.ReverseRGB(0xFF76B295),
        Clockwise = false,
        PaddingX = 0,
        PaddingY = 0,
        BlockRenderX = true,
        BlockRenderY = true,
        BlockReserveY = true,
    }
end
-- Config.HunterConfig.Stamina = nil
---@return OverlayStatusHunterConfig
local function NewHunterConfig()
    local conf = {
        Stamina = {
            Enable = true,
            Segmented = true,
            SegmentValue = 100,
            SegmentRingMargin = 2 *Scale,
            SegmentRingWidth = 6 *Scale,
            AutoHide = true,
            DisappearDelay = 2,
            ShowUsedStamina = true,
            UsedStaminaDelay = 0.5,
            UsedStaminaFadeTime = 2,
            UsedStaminaColor = 0xFFFFFFFF,

            RelativePosition = true,
            WorldOffsetX = 0,
            WorldOffsetY = 1.5,
            WorldOffsetZ = 0,
            RelativeOffsetX = 200,
            RelativeOffsetY = 0,
            FixedOffsetX = ScreenWidth*0.6,
            FixedOffsetY = ScreenHeight*0.6,

            StaminaCircle = NewStaminaRingConfig(),
            EnableColorTransition = true,
            TransitionToColor = Draw.ReverseRGB(0xFF8EB116),
            ThresholdRatio = 0.25,
            ThresholdValue = 30,
            ThresholdColor = Draw.ReverseRGB(0xFFFF0000),

            InsectStaminaCircle = NewStaminaRingConfig(),
            InsectStaminaCircleCenterPlayer = true,
            InsectEnableColorTransition = true,
            InsectTransitionToColor = Draw.ReverseRGB(0xFF8EB116),
            InsectThresholdRatio = 0.25,
            InsectThresholdValue = 30,
            InsectThresholdColor = Draw.ReverseRGB(0xFFFF0000),
        }
    }

    conf.Stamina.InsectStaminaCircle.Color = Draw.ReverseRGB(0xFFDCDC4C)
    conf.Stamina.InsectStaminaCircle.Radius = 18 *Scale
    conf.Stamina.InsectStaminaCircle.RingWidth = 6 *Scale
    
    return conf
end

---@class OverlayStatusGroupConfig
---@field OffsetX number
---@field OffsetY number
---@field Columns number
---@field ShowIcon boolean
---@field ShowTime boolean
---@field ShowName boolean
---@field Configs table<string, OverlayStatusSkillStatusConfig>

---@return OverlayStatusGroupConfig
local function NewGroupConfig()
    return {
        OffsetX = 0,
        OffsetY = 0,
        Columns = 10,

        ShowIcon = true,
        ShowTime = true,
        ShowName = true,

        Configs = {},
    }
end

---@return OverlayStatusBuffWidgetConfig
local function NewBuffWidgetConfig()
    return {
        Enable = false, -- under developing
        MergeAllBuffs = true,
        OffsetX = ScreenWidth*0.2, -- merge mode
        OffsetY = ScreenHeight*0.15, -- merge mode
        Columns = 10,
        
        SkillConfig = NewGroupConfig(),
        MusicSkillConfig = NewGroupConfig(),
        OtomoSkillConfig = NewGroupConfig(),
        ItemBuffConfig = NewGroupConfig(),
        ASkillConfig = NewGroupConfig(),
        WeaponConfig = NewGroupConfig(),
    }
end

---@return OverlayStatusConfig
local function NewDefaultConfig()
    local defaultConfig = {
        Enable = true,

        HunterConfig = NewHunterConfig(),
        BuffWidgetConfig = NewBuffWidgetConfig(),
    }
    -- defaultConfig.Zako.Enable = false
    -- defaultConfig.Animal.Enable = false

    return defaultConfig
end

-- Config.HunterConfig.Stamina.InsectStaminaCircle = nil

local function InitConfigurations()
    Config = Utils.MergeTablesRecursive(NewDefaultConfig(), Config)

    local function InitSkillConfig(conf)
        conf = Utils.MergeTablesRecursive(NewGroupConfig(), conf)

        for key, skillConf in pairs(conf.Configs) do
            conf.Configs[key] = Utils.MergeTablesRecursive(NewDefaultSkillConfig(key), skillConf)
        end

        return conf
    end

    mod.Config.StatusConfig = Config
    mod.SaveConfig()
end

InitConfigurations()

local WidgetConfig = Config.BuffWidgetConfig

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitSkillConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.SkillConfig.Configs[key] then
        WidgetConfig.SkillConfig.Configs[key] = NewDefaultSkillConfig(key, name)
    end

    return WidgetConfig.SkillConfig.Configs[key]
end

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitMusicSkillConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.MusicSkillConfig.Configs[key] then
        WidgetConfig.MusicSkillConfig.Configs[key] = NewDefaultSkillConfig(key, name)
        mod.SaveConfig()
    end

    return WidgetConfig.MusicSkillConfig.Configs[key]
end

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitOtomoSkillConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.OtomoSkillConfig.Configs[key] then
        WidgetConfig.OtomoSkillConfig.Configs[key] = NewDefaultSkillConfig(key, name)
        mod.SaveConfig()
    end

    return WidgetConfig.OtomoSkillConfig.Configs[key]
end

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitItemConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.ItemBuffConfig.Configs[key] then
        WidgetConfig.ItemBuffConfig.Configs[key] = NewDefaultSkillConfig(key, name)
        mod.SaveConfig()
    end

    return WidgetConfig.ItemBuffConfig.Configs[key]
end

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitASkillConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.ASkillConfig.Configs[key] then
        WidgetConfig.ASkillConfig.Configs[key] = NewDefaultSkillConfig(key, name)
        mod.SaveConfig()
    end

    return WidgetConfig.ASkillConfig.Configs[key]
end

---@return OverlayStatusSkillStatusConfig
function Config.GetOrInitWeaponConfig(key, name)
    key = tostring(key)
    if not WidgetConfig.WeaponConfig.Configs[key] then
        WidgetConfig.WeaponConfig.Configs[key] = NewDefaultSkillConfig(key, name)
        mod.SaveConfig()
    end

    return WidgetConfig.WeaponConfig.Configs[key]
end

---@param conf OverlayStatusGroupConfig
local function GroupConfigMenu(conf)
	local configChanged = false
    local changed = false

    if not WidgetConfig.MergeAllBuffs then
        changed, conf.OffsetX = imgui.drag_float("OffsetX", conf.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, conf.OffsetY = imgui.drag_float("OffsetY", conf.OffsetY, 1, -h, h)
        configChanged = configChanged or changed
        changed, conf.Columns = imgui.drag_int("Columns", conf.Columns, 1, 1, 100)
        configChanged = configChanged or changed
    end

    changed, conf.ShowIcon = imgui.checkbox("Show Icon", conf.ShowIcon)
    configChanged = configChanged or changed
    changed, conf.ShowTime = imgui.checkbox("Show Time", conf.ShowTime)
    configChanged = configChanged or changed
    changed, conf.ShowName = imgui.checkbox("Show Name", conf.ShowName)
    configChanged = configChanged or changed

    Imgui.Tree("Configs", function ()
        for key, config in pairs(conf.Configs) do
            Imgui.Tree(config.DisplayName, function ()
                local skillConfigChanged = false
                changed, config.Enable = imgui.checkbox("Enable", config.Enable)
                configChanged = configChanged or changed
            
                changed, config.DisplayName = imgui.input_text("Display Name", config.DisplayName)
                skillConfigChanged = skillConfigChanged or changed
                changed, config.Text = Draw.FontConfigMenu(config.Text, "Text Style")
                skillConfigChanged = skillConfigChanged or changed
                changed, config.Circle = Draw.CircleConfigMenu(config.Circle, "Circle Style")
                skillConfigChanged = skillConfigChanged or changed

                if skillConfigChanged then
                    conf.Configs[key] = config
                end

                configChanged = configChanged or skillConfigChanged
            end)
        end
    end)

    return configChanged, conf
end

mod.SubMenu("Player Status", function()
	local configChanged = false
    local changed = false

    changed, Config.Enable = imgui.checkbox("Enable", Config.Enable)
    configChanged = configChanged or changed

    Imgui.Tree("Stamina Widget (Player and Insect)", function ()
        local conf = Config.HunterConfig.Stamina

        changed, conf.Enable = imgui.checkbox("Enable", conf.Enable)
        configChanged = configChanged or changed

        changed, conf.AutoHide = imgui.checkbox("Auto Hide", conf.AutoHide)
        configChanged = configChanged or changed
        if conf.AutoHide then
            changed, conf.DisappearDelay = imgui.drag_float("Auto Hide Delay", conf.DisappearDelay, 0.1, 0, 10)
            configChanged = configChanged or changed
        end

        Imgui.Tree("Position", function ()
            changed, conf.RelativePosition = imgui.checkbox("Player Relative Position", conf.RelativePosition)
            configChanged = configChanged or changed
            if conf.RelativePosition then
                changed, conf.WorldOffsetX = imgui.drag_float("World Offset X", conf.WorldOffsetX, 0.01, -w, w)
                configChanged = configChanged or changed
                changed, conf.WorldOffsetY = imgui.drag_float("World Offset Y", conf.WorldOffsetY, 0.01, -h, h)
                configChanged = configChanged or changed
                changed, conf.WorldOffsetZ = imgui.drag_float("World Offset Z", conf.WorldOffsetZ, 0.01, -h, h)
                configChanged = configChanged or changed

                changed, conf.RelativeOffsetX = imgui.drag_float("Screen Offset X", conf.RelativeOffsetX, 1, -w, w)
                configChanged = configChanged or changed
                changed, conf.RelativeOffsetY = imgui.drag_float("Screen Offset Y", conf.RelativeOffsetY, 1, -h, h)
                configChanged = configChanged or changed
            else
                changed, conf.FixedOffsetX = imgui.drag_float("Screen Offset X", conf.FixedOffsetX, 1, -w, w)
                configChanged = configChanged or changed
                changed, conf.FixedOffsetY = imgui.drag_float("Screen Offset Y", conf.FixedOffsetY, 1, -h, h)
                configChanged = configChanged or changed
            end
        end)

        Imgui.Tree("Player Stamina", function ()
            changed, conf.StaminaCircle.Enable = imgui.checkbox("Enable", conf.StaminaCircle.Enable)
            configChanged = configChanged or changed

            changed, conf.Segmented = imgui.checkbox("Segmented", conf.Segmented)
            configChanged = configChanged or changed
            if conf.Segmented then
                changed, conf.SegmentValue = imgui.drag_int("Segment Max Value", conf.SegmentValue, 1, 1, 500)
                configChanged = configChanged or changed
                changed, conf.SegmentRingMargin = imgui.drag_int("Segment Ring Margin", conf.SegmentRingMargin, 1, -1000, 1000)
                configChanged = configChanged or changed
                changed, conf.SegmentRingWidth = imgui.drag_int("Segment Ring Width", conf.SegmentRingWidth, 1, 1, 100)
                configChanged = configChanged or changed
            end
            
            changed, conf.ShowUsedStamina = imgui.checkbox("Show Used Stamina", conf.ShowUsedStamina)
            configChanged = configChanged or changed
            if conf.ShowUsedStamina then
                Imgui.Tree("Used Stamina Color", function ()
                    changed, conf.UsedStaminaColor = imgui.color_picker("Color", conf.UsedStaminaColor)
                    configChanged = configChanged or changed
                end)
            end

            changed, conf.EnableColorTransition = imgui.checkbox("Enable Color Transition", conf.EnableColorTransition)
            configChanged = configChanged or changed
            if conf.EnableColorTransition then
                Imgui.Tree("Color Transition", function ()
                    changed, conf.ThresholdRatio = imgui.drag_float("Low Value Ratio", conf.ThresholdRatio, 0.001, 0, 1)
                    configChanged = configChanged or changed
                    changed, conf.ThresholdValue = imgui.drag_float("Low Value", conf.ThresholdValue, 1, 0, 200)
                    configChanged = configChanged or changed

                    changed, conf.TransitionToColor = imgui.color_picker("Transition To Color", conf.TransitionToColor)
                    configChanged = configChanged or changed
                    changed, conf.ThresholdColor = imgui.color_picker("Low Value Color", conf.ThresholdColor)
                    configChanged = configChanged or changed
                end)
            end

            changed, conf.StaminaCircle = Draw.CircleConfigMenu(conf.StaminaCircle, "Circle Style")
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Insect Stamina", function ()
            local conf = Config.HunterConfig.Stamina

            changed, conf.InsectStaminaCircle.Enable = imgui.checkbox("Enable", conf.InsectStaminaCircle.Enable)
            configChanged = configChanged or changed

            changed, conf.InsectStaminaCircleCenterPlayer = imgui.checkbox("Offset Player Stamina Circle Center", conf.InsectStaminaCircleCenterPlayer)
            configChanged = configChanged or changed

            changed, conf.InsectEnableColorTransition = imgui.checkbox("Enable Color Transition", conf.InsectEnableColorTransition)
            configChanged = configChanged or changed
            if conf.InsectEnableColorTransition then
                Imgui.Tree("Color Transition", function ()
                    changed, conf.InsectThresholdRatio = imgui.drag_float("Low Value Ratio", conf.InsectThresholdRatio, 0.001, 0, 1)
                    configChanged = configChanged or changed
                    changed, conf.InsectThresholdValue = imgui.drag_float("Low Value", conf.InsectThresholdValue, 1, 0, 200)
                    configChanged = configChanged or changed

                    changed, conf.InsectTransitionToColor = imgui.color_picker("Transition To Color", conf.InsectTransitionToColor)
                    configChanged = configChanged or changed
                    changed, conf.InsectThresholdColor = imgui.color_picker("Low Value Color", conf.InsectThresholdColor)
                    configChanged = configChanged or changed
                end)
            end

            changed, conf.InsectStaminaCircle = Draw.CircleConfigMenu(conf.InsectStaminaCircle, "Circle Style")
            configChanged = configChanged or changed
        end)
    end)

    -- TODO: Mantle Status (buff time, cooldown)
    -- TODO: Otomo cooldown

    Imgui.Tree("Buff Widget [alpha]", function ()
        local conf = Config.BuffWidgetConfig
        changed, conf.Enable = imgui.checkbox("Enable [dev]", conf.Enable)
        configChanged = configChanged or changed
        changed, conf.MergeAllBuffs = imgui.checkbox("Merge All Buffs", conf.MergeAllBuffs)
        configChanged = configChanged or changed
        if conf.MergeAllBuffs then
            changed, conf.OffsetX = imgui.drag_float("OffsetX", conf.OffsetX, 1, -w, w)
            configChanged = configChanged or changed
            changed, conf.OffsetY = imgui.drag_float("OffsetY", conf.OffsetY, 1, -h, h)
            configChanged = configChanged or changed
            changed, conf.Columns = imgui.drag_int("Columns", conf.Columns, 1, 1, 100)
            configChanged = configChanged or changed
        end

        Imgui.Tree("Skill Configs", function ()
            changed, conf.SkillConfig = GroupConfigMenu(conf.SkillConfig)
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Music Skill Configs", function ()
            changed, conf.MusicSkillConfig = GroupConfigMenu(conf.MusicSkillConfig)
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Otomo Skill Configs", function ()
            changed, conf.OtomoSkillConfig = GroupConfigMenu(conf.OtomoSkillConfig)
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Item Buffs Configs", function ()
            changed, conf.ItemBuffConfig = GroupConfigMenu(conf.ItemBuffConfig)
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Mantle Configs", function ()
            changed, conf.ASkillConfig = GroupConfigMenu(conf.ASkillConfig)
            configChanged = configChanged or changed
        end)

        Imgui.Tree("Weapon Configs", function ()
            changed, conf.WeaponConfig = GroupConfigMenu(conf.WeaponConfig)
            configChanged = configChanged or changed
        end)
    end)

    if configChanged then
        mod.Config.StatusConfig = Config
    end

    return configChanged
end)

return Config
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
local OverlayDrawHpConf = require("mhwilds_overlay.draw.hp_conf")


local ScreenWidth, ScreenHeight = Core.GetScreenSize()

local Config = mod.Config.BossConfig

local DEFAULT_COLOR = 0xFFB5B5B5
local DEFAULT_COND_COLORS = {
    -- [CONST.EnemyConditionType.Angry] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.Tired] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.Depletion] = DEFAULT_COLOR,

    [CONST.EnemyConditionType.Poison] = 0xFF7607EA,
    [CONST.EnemyConditionType.Poison_Em] = 0xFF7607EA,

    [CONST.EnemyConditionType.Paralyse] = 0xFFDDB80D,
    [CONST.EnemyConditionType.Paralyse_Em] = 0xFFDDB80D,

    [CONST.EnemyConditionType.Sleep] = 0xFF08DDBE,
    [CONST.EnemyConditionType.Sleep_Em] = 0xFF08DDBE,

    [CONST.EnemyConditionType.Blast] = 0xFFEA700D,
    [CONST.EnemyConditionType.BlastReaction] = 0xFFEA700D,
    [CONST.EnemyConditionType.Blast_Em] = 0xFFEA700D,
    [CONST.EnemyConditionType.BlastReaction_Em] = 0xFFEA700D,

    [CONST.EnemyConditionType.Ride] = 0xFFEA0050, -- TODO
    [CONST.EnemyConditionType.Stamina] = 0xFFF3D35F,

    [CONST.EnemyConditionType.Stun] = 0xFFDFD900,
    [CONST.EnemyConditionType.Stun_Em] = 0xFFDFD900,

    -- [CONST.EnemyConditionType.Capture] = 0xFF,

    [CONST.EnemyConditionType.Flash] = 0xFFDDB80D,
    [CONST.EnemyConditionType.Flash_Em] = 0xFFDDB80D,

    [CONST.EnemyConditionType.Ear] = 0xFFEA0050, -- TODO

    [CONST.EnemyConditionType.Koyasi] = 0xFF716704,

    -- [CONST.EnemyConditionType.WeakAttrSlinger] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.WeakAttrBoost] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.LightPlant] = DEFAULT_COLOR,

    [CONST.EnemyConditionType.Parry] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Parry_NPC] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Block] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Block_NPC] = DEFAULT_COLOR,

    -- [CONST.EnemyConditionType.SandDig] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.Scar] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.FieldPitfall] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.SmokeBall] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.EmLead] = DEFAULT_COLOR,
    -- [CONST.EnemyConditionType.Ryuki] = DEFAULT_COLOR,

    [CONST.EnemyConditionType.Trap_Fall] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Paralyse] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Ivy] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Paralyse_Animal] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Paralyse_Otomo] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Bound_NPC] = DEFAULT_COLOR,
    [CONST.EnemyConditionType.Trap_Slinger] = DEFAULT_COLOR,
}

local DEFAULT_PART_COLOR = 0xFF4AC92C
local DEFAULT_PART_COLORS = {
    -- NO
}

local DEFAULT_COND_ENABLED = {
    [CONST.EnemyConditionType.Poison] = true,
    [CONST.EnemyConditionType.Poison_Em] = true,

    [CONST.EnemyConditionType.Paralyse] = true,
    [CONST.EnemyConditionType.Paralyse_Em] = true,

    [CONST.EnemyConditionType.Sleep] = true,
    [CONST.EnemyConditionType.Sleep_Em] = true,

    [CONST.EnemyConditionType.Blast] = true,
    [CONST.EnemyConditionType.Blast_Em] = true,

    [CONST.EnemyConditionType.Ride] = true,
    -- [CONST.EnemyConditionType.Stamina] = true,

    [CONST.EnemyConditionType.Stun] = true,
    [CONST.EnemyConditionType.Stun_Em] = true,

    [CONST.EnemyConditionType.Flash] = true,
    [CONST.EnemyConditionType.Flash_Em] = true,

    [CONST.EnemyConditionType.Parry] = true,
    -- [CONST.EnemyConditionType.Parry_NPC] = true,
    [CONST.EnemyConditionType.Block] = true,
    -- [CONST.EnemyConditionType.Block_NPC] = true,

    [CONST.EnemyConditionType.Trap_Fall] = true,
    [CONST.EnemyConditionType.Trap_Paralyse] = true,
    [CONST.EnemyConditionType.Trap_Ivy] = true,
    [CONST.EnemyConditionType.Trap_Paralyse_Animal] = true,
    [CONST.EnemyConditionType.Trap_Paralyse_Otomo] = true,
    [CONST.EnemyConditionType.Trap_Bound_NPC] = true,
    [CONST.EnemyConditionType.Trap_Slinger] = true,

    [CONST.EnemyConditionType.SkillStabbing_P1] = true,
    [CONST.EnemyConditionType.SkillStabbing_P2] = true,
    [CONST.EnemyConditionType.SkillStabbing_P3] = true,
    [CONST.EnemyConditionType.SkillStabbing_P4] = true,
}

local DEFAULT_COND_USE_DEFAULT_COLOR = {
    [CONST.EnemyConditionType.Parry] = true,
    [CONST.EnemyConditionType.Parry_NPC] = true,
    [CONST.EnemyConditionType.Block] = true,
    [CONST.EnemyConditionType.Block_NPC] = true,

    [CONST.EnemyConditionType.Trap_Fall] = true,
    [CONST.EnemyConditionType.Trap_Paralyse] = true,
    [CONST.EnemyConditionType.Trap_Ivy] = true,
    [CONST.EnemyConditionType.Trap_Paralyse_Animal] = true,
    [CONST.EnemyConditionType.Trap_Paralyse_Otomo] = true,
    [CONST.EnemyConditionType.Trap_Bound_NPC] = true,
    [CONST.EnemyConditionType.Trap_Slinger] = true,
}

local SUPPORTED_CONDITIONS = {
    CONST.EnemyConditionType.Poison,
    CONST.EnemyConditionType.Poison_Em,
    CONST.EnemyConditionType.Paralyse,
    CONST.EnemyConditionType.Paralyse_Em,
    CONST.EnemyConditionType.Sleep,
    CONST.EnemyConditionType.Sleep_Em,
    CONST.EnemyConditionType.Blast,
    CONST.EnemyConditionType.BlastReaction,
    CONST.EnemyConditionType.Blast_Em,
    CONST.EnemyConditionType.BlastReaction_Em,
    CONST.EnemyConditionType.Ride,
    CONST.EnemyConditionType.Stamina,
    CONST.EnemyConditionType.Stun,
    CONST.EnemyConditionType.Stun_Em,
    CONST.EnemyConditionType.Flash,
    CONST.EnemyConditionType.Flash_Em,
    CONST.EnemyConditionType.Ear,
    CONST.EnemyConditionType.Parry,
    CONST.EnemyConditionType.Parry_NPC,
    CONST.EnemyConditionType.Block,
    CONST.EnemyConditionType.Block_NPC,
    CONST.EnemyConditionType.Trap_Fall,
    CONST.EnemyConditionType.Trap_Paralyse,
    CONST.EnemyConditionType.Trap_Ivy,
    CONST.EnemyConditionType.Trap_Paralyse_Animal,
    CONST.EnemyConditionType.Trap_Paralyse_Otomo,
    CONST.EnemyConditionType.Trap_Bound_NPC,
    CONST.EnemyConditionType.Trap_Slinger,

    CONST.EnemyConditionType.SkillStabbing_P1,
    CONST.EnemyConditionType.SkillStabbing_P2,
    CONST.EnemyConditionType.SkillStabbing_P3,
    CONST.EnemyConditionType.SkillStabbing_P4,
    CONST.EnemyConditionType.SandDig,
    CONST.EnemyConditionType.Scar,
    CONST.EnemyConditionType.FieldPitfall,
    CONST.EnemyConditionType.SmokeBall,
    CONST.EnemyConditionType.EmLead,
    CONST.EnemyConditionType.Ryuki,
}

local DEFAULT_PART_DISABLED = {
    CONST.EnemyPartType.HIDE,
}

local SUPPORTED_PARTS = {
    CONST.EnemyPartType.FULL_BODY,
    CONST.EnemyPartType.HEAD,
    CONST.EnemyPartType.UPPER_BODY,
    CONST.EnemyPartType.BODY,
    CONST.EnemyPartType.TAIL,
    CONST.EnemyPartType.TAIL_TIP,
    CONST.EnemyPartType.NECK,
    CONST.EnemyPartType.TORSO,
    CONST.EnemyPartType.STOMACH,
    CONST.EnemyPartType.BACK,
    CONST.EnemyPartType.FRONT_LEGS,
    CONST.EnemyPartType.LEFT_FRONT_LEG,
    CONST.EnemyPartType.RIGHT_FRONT_LEG,
    CONST.EnemyPartType.HIND_LEGS,
    CONST.EnemyPartType.LEFT_HIND_LEG,
    CONST.EnemyPartType.RIGHT_HIND_LEG,
    CONST.EnemyPartType.LEFT_LEG,
    CONST.EnemyPartType.RIGHT_LEG,
    CONST.EnemyPartType.LEFT_LEG_FRONT_AND_REAR,
    CONST.EnemyPartType.RIGHT_LEG_FRONT_AND_REAR,
    CONST.EnemyPartType.LEFT_WING,
    CONST.EnemyPartType.RIGHT_WING,
    CONST.EnemyPartType.ASS,
    CONST.EnemyPartType.NAIL,
    CONST.EnemyPartType.LEFT_NAIL,
    CONST.EnemyPartType.RIGHT_NAIL,
    CONST.EnemyPartType.TONGUE,
    CONST.EnemyPartType.PETAL,
    CONST.EnemyPartType.VEIL,
    CONST.EnemyPartType.SAW,
    CONST.EnemyPartType.FEATHER,
    CONST.EnemyPartType.TENTACLE,
    CONST.EnemyPartType.UMBRELLA,
    CONST.EnemyPartType.LEFT_FRONT_ARM,
    CONST.EnemyPartType.RIGHT_FRONT_ARM,
    CONST.EnemyPartType.LEFT_SIDE_ARM,
    CONST.EnemyPartType.RIGHT_SIDE_ARM,
    CONST.EnemyPartType.LEFT_HIND_ARM,
    CONST.EnemyPartType.RIGHT_HIND_ARM,
    CONST.EnemyPartType.Head, -- WTF is this?
    CONST.EnemyPartType.CHEST,
    CONST.EnemyPartType.MANTLE,
    CONST.EnemyPartType.MANTLE_UNDER,
    CONST.EnemyPartType.POISONOUS_THORN,
    CONST.EnemyPartType.ANTENNAE,
    CONST.EnemyPartType.LEFT_WING_LEGS,
    CONST.EnemyPartType.RIGHT_WING_LEGS,
    CONST.EnemyPartType.WATERFILM_RIGHT_HEAD,
    CONST.EnemyPartType.WATERFILM_LEFT_HEAD,
    CONST.EnemyPartType.WATERFILM_RIGHT_BODY,
    CONST.EnemyPartType.WATERFILM_LEFT_BODY,
    CONST.EnemyPartType.WATERFILM_RIGHT_FRONT_LEG,
    CONST.EnemyPartType.WATERFILM_LEFT_FRONT_LEG,
    CONST.EnemyPartType.WATERFILM_TAIL,
    CONST.EnemyPartType.WATERFILM_LEFT_TAIL,
    CONST.EnemyPartType.MOUTH,
    CONST.EnemyPartType.TRUNK,
    CONST.EnemyPartType.LEFT_WING_BLADE,
    CONST.EnemyPartType.RIGHT_WING_BLADE,
    CONST.EnemyPartType.FROZEN_CORE_HEAD,
    CONST.EnemyPartType.FROZEN_CORE_TAIL,
    CONST.EnemyPartType.FROZEN_CORE_WAIST,
    CONST.EnemyPartType.FROZEN_BIGCORE_BEFORE,
    CONST.EnemyPartType.FROZEN_BIGCORE_AFTER,
    CONST.EnemyPartType.NOSE,
    CONST.EnemyPartType.HEAD_WEAR,
    CONST.EnemyPartType.HEAD_HIDE,
    CONST.EnemyPartType.WING_ARM,
    CONST.EnemyPartType.WING_ARM_WEAR,
    CONST.EnemyPartType.LEFT_WING_ARM_WEAR,
    CONST.EnemyPartType.RIGHT_WING_ARM_WEAR,
    CONST.EnemyPartType.LEFT_WING_ARM,
    CONST.EnemyPartType.RIGHT_WING_ARM,
    CONST.EnemyPartType.LEFT_WING_ARM_HIDE,
    CONST.EnemyPartType.RIGHT_WING_ARM_HIDE,
    CONST.EnemyPartType.CHELICERAE,
    CONST.EnemyPartType.BOTH_WINGS,
    CONST.EnemyPartType.BOTH_WINGS_BLADE,
    CONST.EnemyPartType.BOTH_LEG,
    CONST.EnemyPartType.ARM,
    CONST.EnemyPartType.LEG,
    CONST.EnemyPartType.HIDE,
    CONST.EnemyPartType.SHARP_CORNERS,
    CONST.EnemyPartType.NEEDLE_HAIR,
    CONST.EnemyPartType.PARALYSIS_CORNERS,
    CONST.EnemyPartType.HEAD_OIL,
    CONST.EnemyPartType.UMBRELLA_OIL,
    CONST.EnemyPartType.TORSO_OIL,
    CONST.EnemyPartType.ARM_OIL,
    CONST.EnemyPartType.WATERFILM_RIGHT_TAIL,
}

-- Config = nil
-- TODO: dynamic width
local DefaultWidth = ScreenWidth*0.15

---@return FontConfig
local function NewDefaultFontStyle()
    return {
        Enable = true,
        Absolute = true,
        OffsetY = 0,
        FontSize = 16 *Scale,
        Color = 0xFFFFFFFF,
        BlockRenderX = false,
        BlockRenderY = false,
    }
end

---@return RectConfig
local function NewDefaultHpRectStyle()
    return {
        Enable = true,
        Absolute = true,
        OffsetY = 24 *Scale,
        Height = 12 *Scale,
        IsFillRect = true,
        Color = Draw.ReverseRGB(0xFF76DCA7), -- 崛起血条颜色
        UseBackground = true,
        BackgroundColor = 0x90000000,
        BlockRenderX = false,
        BlockRenderY = true,
        ShrinkSize = 1,
    }
end

local function NewScarColorsConfig()
    return {
        Enable = true,
        NormalColor = Draw.ReverseRGB(0xFF76DCA7),
        TearColor = Draw.ReverseRGB(0xFFFFFF00),
        RawColor = Draw.ReverseRGB(0xFFFF0000),

        ShowRideScar = false,
        UseSpecialRideScarColor = false,
        RideColor = Draw.ReverseRGB(0xFF00FFFF),

        ShowLegendaryScar = true,
        UseSpecialLegendaryScarColor = false,
        LegendaryColor = Draw.ReverseRGB(0xFF800080),
    }
end

---@return CircleConfig
local function NewScarRingConfig()
    return {
        Enable = true,
        OffsetY = 0,
        Absolute = true,
        IsFill = true,
        IsRing = true,
        Radius = 14 *Scale,
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

---@return FontConfig
local function NewScarRingTextConfig()
    return {
        Enable = true,
        Absolute = true,
        OffsetX = 2 *Scale,
        OffsetY = 2 *Scale,
        Color = 0xFFFFFFFF,
        VerticalCenter = true,
        HorizontalCenter = true,
        FontSize = 16 *Scale,
    }
end

local function NewDefaultTheme()
    local theme = OverlayDrawHpConf.NewDefaultTheme()
    theme.EnemyIcon = {
        Enable = false,
        BackgroundSize = 120 *Scale,
        EnemySize = 64 *Scale,
    }

    if theme.Condition == nil then
        theme.Condition = {
            Enable = true,
            Width = DefaultWidth *Scale,
            Height = 12 *Scale,
            OffsetX = 0,
            OffsetY = 0,

            Columns = 3,
            ColumnMargin = 10 *Scale,
            RowMargin = 10 *Scale,

            OnlyInBattle = false,
            AlwaysShow = false,
            AutoHide = true,
            AutoHideSeconds = 15,

            ShowCondName = true,
            ShowCondLevel = true,
            ShowCondValue = true,
            ShowCondMaxValue = true,
            FontStyle = NewDefaultFontStyle(),

            Conditions = {},
            CondRect = NewDefaultHpRectStyle(),
        }
        theme.Condition.CondRect.Color = DEFAULT_COLOR
        for _, cond in pairs(SUPPORTED_CONDITIONS) do
            local name = CONST.EnemyConditionTypeNames[cond]
            theme.Condition.Conditions[name] = {
                Enable = false,
                AlwaysShow = false,
                DisplayName = string.gsub(" "..string.lower(name), "%W%l", string.upper):sub(2),
                
                UseDefaultFontStyle = true,
                FontStyle = NewDefaultFontStyle(),
                UseDefaultRectStyle = true,
                Rect = NewDefaultHpRectStyle(),
            }

            if 34 <= cond and cond <= 37 then
                theme.Condition.Conditions[name].DisplayName = Core.GetSkillName(147) .. string.format("_P%d", cond-33) -- 锁刃刺击
            end

            if DEFAULT_COND_COLORS[cond] then
                theme.Condition.Conditions[name].UseDefaultRectStyle = false
                theme.Condition.Conditions[name].Rect.Color = Core.ReverseRGB(DEFAULT_COND_COLORS[cond])
            end
            if DEFAULT_COND_ENABLED[cond] ~= nil then
                theme.Condition.Conditions[name].Enable = DEFAULT_COND_ENABLED[cond]
            end
            if DEFAULT_COND_USE_DEFAULT_COLOR[cond] ~= nil then
                theme.Condition.Conditions[name].UseDefaultRectStyle = true
            end
        end
    end

    if theme.Part == nil then
        theme.Part = {
            Enable = true,
            Width = DefaultWidth *Scale,
            OffsetX = 0,
            OffsetY = 0,

            Columns = 2,
            ColumnMargin = 10 *Scale,
            RowMargin = 10 *Scale,

            MenuOptionsShowOnlyCurrentTarget = true,

            OnlyInBattle = false,
            AlwaysShow = false,
            AutoHide = true,
            AutoHideSeconds = 15,
            -- SortByLastHitTime = false, -- todo
            OnlyBreakable = false,
            BreakableAlwaysShow = false,
            OnlySeverable = false,
            SeverableAlwaysShow = false,
            BrokenNoAlwaysShow = true,
            HideHigherThanMaxHpPart = true,

            ShowPartName = true,
            ShowPartLevel = true,
            ShowPartHP = true,
            ShowPartMaxHP = true,
            ShowBreakableIcon = true,
            ShowSeverableIcon = true,
            FontStyle = NewDefaultFontStyle(),
            Parts = {},
            PartRect = NewDefaultHpRectStyle(),
            Scar = NewScarColorsConfig(),
            ScarRing = NewScarRingConfig(),
            ScarLevelText = NewScarRingTextConfig(),
        }
        -- parts
        for _, part in pairs(SUPPORTED_PARTS) do
            local name = CONST.EnemyPartsTypeNames[part]
            local displayName = Core.GetPartTypeName(part) or name
            displayName = string.gsub(" "..string.lower(displayName), "%W%l", string.upper):sub(2)
            theme.Part.Parts[name] = {
                Enable = true,
                AlwaysShow = false,
                DisplayName = displayName,
                UseDefaultFontStyle = true,
                FontStyle = NewDefaultFontStyle(),
                UseDefaultPartStyle = true,
                Rect = NewDefaultHpRectStyle(),
                UseDefaultScarStyle = true,
                Scar = NewScarColorsConfig(),
                ScarRing = NewScarRingConfig(),
                UseDefaultScarLevelFontStyle = true,
                ScarLevelText = NewScarRingTextConfig(),
            }
            if DEFAULT_PART_COLORS[part] then
                theme.Part.Parts[name].Color = Core.ReverseRGB(DEFAULT_PART_COLORS[part])
            end
            if DEFAULT_PART_DISABLED[part] then
                theme.Part.Parts[name].Enable = false
            end
        end
    end

    if theme.Scar == nil then
        theme.Scar = {
            Enable = false,
            Width = DefaultWidth *Scale,
            Height = 4 *Scale,
            OffsetX = 0,
            OffsetY = 0,

            Columns = 2,
            ColumnMargin = 10 *Scale,
            RowMargin = 10 *Scale,

            OnlyInBattle = false,
            AlwaysShow = false,
            AutoHide = true,
            AutoHideSeconds = 15,
            -- SortByLastHitTime = false, -- todo
            
            ShowPartName = true,
            ShowScarLevel = true,
            ShowScarIndex = true,
            ShowScarHP = true,
            ShowScarMaxHP = true,

            FontStyle = NewDefaultFontStyle(),
            ScarColors = NewScarColorsConfig(),
            ScarRect = NewDefaultHpRectStyle(),
        }
    end

    if theme.CaptureStatus == nil then
        theme.CaptureStatus = {
            Enable = true,
            ShowCaptureIcon = true,
            ShowCaptureThreshold = true,
        }
    end

    return theme
end

local function NewStylizedConfig()
    local theme = {
        Header = {
            Height = 40 *Scale,
        },
        EnemyIcon = {
            Enable = true,
        },
        Hp = {
            OffsetX = -22 *Scale,
            ParallelogramOffsetX = 18 *Scale,
            Height = 14 *Scale,
            ShrinkSize = 2 *Scale,
        },
        Stamina = {
            OffsetX = -8 *Scale,
            OffsetY = 2 *Scale,
            ParallelogramOffsetX = -14 *Scale,
            Width = 450 *Scale,
            Height = 9 *Scale,
            ShrinkSize = 1,
        },
        Angry = {
            OffsetX = -11 *Scale,
            OffsetY = 3 *Scale,
            ParallelogramOffsetX = -14 *Scale,
            Width = 420 *Scale,
            Height = 8 *Scale,
            ShrinkSize = 1,
        }
    }

    if theme.Condition == nil then
        theme.Condition = {
            Width = 580 *Scale,
            Conditions = {},
            CondRect = {
                ParallelogramOffsetX = -14 *Scale,
            },
        }
        for _, cond in pairs(SUPPORTED_CONDITIONS) do
            local name = CONST.EnemyConditionTypeNames[cond]
            theme.Condition.Conditions[name] = {
                Rect = {
                    ParallelogramOffsetX = -14 *Scale,
                },
            }
        end
    end

    if theme.Part == nil then
        theme.Part = {
            Width = 580 *Scale,
            Parts = {},
            PartRect = {
                ParallelogramOffsetX = -14 *Scale,
            },
        }
        for _, part in pairs(SUPPORTED_PARTS) do
            local name = CONST.EnemyPartsTypeNames[part]
            theme.Part.Parts[name] = {
                Rect = {
                    ParallelogramOffsetX = -14 *Scale,
                },
            }
        end
    end

    if theme.Scar == nil then
        theme.Scar = {
            Width = 580 *Scale,
            ScarRect = {
                ParallelogramOffsetX = -14 *Scale,
            },
        }
    end

    return theme
end

local function NewStylizedTheme()
    return Utils.MergeTablesRecursive(NewDefaultTheme(), NewStylizedConfig())
end

local CONF_STYLIZED = mod.ModName.."/boss_widget_theme_stylized.json"
local ThemeStylized = mod.LoadConfig(CONF_STYLIZED)
local CONF_NORMAL = mod.ModName.."/boss_widget_theme_simple.json"
local ThemeNormal = mod.LoadConfig(CONF_NORMAL)
local CONF_CUSTOM = mod.ModName.."/boss_widget_theme_custom.json"
local ThemeCustom = mod.LoadConfig(CONF_CUSTOM)

local Themes = {
    "Stylized",
    "Simple",
}

local function InitConfig(Config, ThemeStylized, ThemeNormal, ThemeCustom)
    Scale = LibConf.UIScale

    local function InitThemeConfigurations()
        local confChanged = false

        -- ThemeStylized.Condition.Conditions[CONST.EnemyConditionTypeNames[34]] = nil
        -- ThemeStylized.Condition.Conditions[CONST.EnemyConditionTypeNames[35]] = nil
        -- ThemeStylized.Condition.Conditions[CONST.EnemyConditionTypeNames[36]] = nil
        -- ThemeStylized.Condition.Conditions[CONST.EnemyConditionTypeNames[37]] = nil
        ThemeStylized = Utils.MergeTablesRecursive(NewStylizedTheme(), ThemeStylized)
        mod.SaveConfig(CONF_STYLIZED, ThemeStylized)

        ThemeNormal = Utils.MergeTablesRecursive(NewDefaultTheme(), ThemeNormal)
        mod.SaveConfig(CONF_NORMAL, ThemeNormal)

        if ThemeCustom ~= nil then
            ThemeCustom = Utils.MergeTablesRecursive(NewDefaultTheme(), ThemeCustom)
            mod.SaveConfig(CONF_CUSTOM, ThemeCustom)
        end
    end

    InitThemeConfigurations()

    mod.Runtime.Themes = {
        ThemeStylized,
        ThemeNormal,
    }
    if ThemeCustom ~= nil then
        table.insert(Themes, "Custom")
        table.insert(mod.Runtime.Themes, ThemeCustom)
    end

    if Config == nil then
        Config = {
            Enable = true,
            PosX = ScreenWidth*0.6,
            PosY = 0,

            ThemeIndex = 1,

            OnlyInBattle = false,
            OnlyDamaged = false,
            DrawPartsFirst = false,
        }

        mod.Config.BossConfig = Config
    end

    if Config.ColumnMargin == nil then
        Config.ColumnMargin = (DefaultWidth + 20) *Scale
    end

    return Config, ThemeStylized, ThemeNormal, ThemeCustom
end

-- Config, ThemeStylized, ThemeNormal = nil, nil, nil
Config, ThemeStylized, ThemeNormal, ThemeCustom = InitConfig(Config, ThemeStylized, ThemeNormal, ThemeCustom)

local LEGAL_OPTIONS = {}

local function GetEnemyLegalOptions(ctx)
    local emID = ctx:get_EmID()
    if LEGAL_OPTIONS[emID] ~= nil then
        return LEGAL_OPTIONS[emID]
    end

    LEGAL_OPTIONS[emID] = {}

    local parts = ctx.Parts
    Core.ForEach(parts._ParamParts._PartsArray._DataArray, function (part, i) -- userdata cParts
        local partsType = Core.FixedToEnum("app.EnemyDef.PARTS_TYPE", part._PartsType._Value)
        LEGAL_OPTIONS[emID][partsType] = true
    end)

    return LEGAL_OPTIONS[emID]
end

local w, h = ScreenWidth, ScreenHeight

mod.SubMenu("Boss Widget Options", function ()
	local configChanged = false
    local changed = false

    if imgui.button("Regenerate Config") then
        Config, ThemeStylized, ThemeNormal, ThemeCustom = InitConfig()
    end

    changed, Config.Enable = imgui.checkbox("Enable", Config.Enable)
    configChanged = configChanged or changed

    changed, Config.ThemeIndex = imgui.combo("Theme", Config.ThemeIndex, Themes)
    configChanged = configChanged or changed

    changed, Config.OnlyInBattle = imgui.checkbox("Only In Battle", Config.OnlyInBattle)
    configChanged = configChanged or changed

    changed, Config.OnlyDamaged = imgui.checkbox("Only Damaged", Config.OnlyDamaged)
    configChanged = configChanged or changed

    changed, Config.PosX = imgui.slider_int("Pos X", Config.PosX, 0, w)
    configChanged = configChanged or changed
    changed, Config.PosY = imgui.slider_int("Pos Y", Config.PosY, 0, h)
    configChanged = configChanged or changed
    changed, Config.ColumnMargin = imgui.slider_int("Multi-Target Margin", Config.ColumnMargin, -w, w)
    configChanged = configChanged or changed

    local theme = mod.Runtime.Themes[Config.ThemeIndex]

    changed, theme = OverlayDrawHpConf.ThemeMenu("HP Widget Options", theme, function ()
        if imgui.tree_node("Enemy Icon") then
            changed, theme.EnemyIcon.Enable = imgui.checkbox("Enable", theme.EnemyIcon.Enable)
            configChanged = configChanged or changed
    
            changed, theme.EnemyIcon.BackgroundSize = imgui.drag_int("Background Image Size", theme.EnemyIcon.BackgroundSize, 1, 12, 240)
            configChanged = configChanged or changed
            changed, theme.EnemyIcon.EnemySize = imgui.drag_int("Enemy Icon Size", theme.EnemyIcon.EnemySize, 1, 12, 240)
            configChanged = configChanged or changed
    
            imgui.tree_pop()
        end
        
        Imgui.Tree("Capture Indicator", function ()
            changed, theme.CaptureStatus.Enable = imgui.checkbox("Enable", theme.CaptureStatus.Enable)
            configChanged = configChanged or changed
            
            -- changed, theme.CaptureStatus.ShowCaptureIcon = imgui.checkbox("Show Capturable (dying) Icon", theme.CaptureStatus.ShowCaptureIcon)
            -- configChanged = configChanged or changed

            -- changed, theme.CaptureStatus.ShowCaptureThreshold = imgui.checkbox("Show Capture Threshold in HP", theme.CaptureStatus.ShowCaptureThreshold)
            configChanged = configChanged or changed
        end)
    end)
    configChanged = configChanged or changed

    changed, Config.DrawPartsFirst = imgui.checkbox("Draw Parts Before Abnormal Status", Config.DrawPartsFirst)
    configChanged = configChanged or changed

    if imgui.tree_node("Abnormal Status Options") then
        changed, theme.Condition.Enable = imgui.checkbox("Enable", theme.Condition.Enable)
        configChanged = configChanged or changed
        
        changed, theme.Condition.Width = imgui.drag_int("Width", theme.Condition.Width, 1, 0, w)
        configChanged = configChanged or changed
        changed, theme.Condition.Height = imgui.slider_int("Height", theme.Condition.Height, 0, 100)
        configChanged = configChanged or changed
        changed, theme.Condition.OffsetX = imgui.drag_int("OffsetX", theme.Condition.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, theme.Condition.OffsetY = imgui.drag_int("OffsetY", theme.Condition.OffsetY, 1, -h, h)
        configChanged = configChanged or changed
    
        changed, theme.Condition.Columns = imgui.slider_int("Columns", theme.Condition.Columns, 0, 10)
        configChanged = configChanged or changed
        changed, theme.Condition.ColumnMargin = imgui.slider_int("Column Margin", theme.Condition.ColumnMargin, 0, 100)
        configChanged = configChanged or changed

        changed, theme.Condition.RowMargin = imgui.slider_int("Row Margin", theme.Condition.RowMargin, 0, 100)
        configChanged = configChanged or changed

        changed, theme.Condition.OnlyInBattle = imgui.checkbox("Only In Battle", theme.Condition.OnlyInBattle)
        configChanged = configChanged or changed

        changed, theme.Condition.AlwaysShow = imgui.checkbox("Always Display", theme.Condition.AlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Condition.AutoHide = imgui.checkbox("Auto Hide", theme.Condition.AutoHide)
        configChanged = configChanged or changed

        if theme.Condition.AutoHide then
            changed, theme.Condition.AutoHideSeconds = imgui.slider_float("Auto Hide Secs", theme.Condition.AutoHideSeconds, 0, 60.0)
            configChanged = configChanged or changed
        end

        imgui.text("")
        imgui.text("=== Conditions Global Style ===")

        changed, theme.Condition.FontStyle = Draw.FontConfigMenu(theme.Condition.FontStyle, "Condition Font Style")
        configChanged = configChanged or changed

        changed, theme.Condition.ShowCondName = imgui.checkbox("Show Condition Name", theme.Condition.ShowCondName)
        configChanged = configChanged or changed
        changed, theme.Condition.ShowCondLevel = imgui.checkbox("Show Condition Level", theme.Condition.ShowCondLevel)
        configChanged = configChanged or changed
        changed, theme.Condition.ShowCondValue = imgui.checkbox("Show Condition Current Value", theme.Condition.ShowCondValue)
        configChanged = configChanged or changed
        changed, theme.Condition.ShowCondMaxValue = imgui.checkbox("Show Condition Max Value", theme.Condition.ShowCondMaxValue)
        configChanged = configChanged or changed

        changed, theme.Condition.CondRect = Draw.RectConfigMenu(theme.Condition.CondRect, "Condition Bar Style")
        configChanged = configChanged or changed

        imgui.text("")
        imgui.text("=== Conditions Style (_Em are caused by creatures like flash bug or other bosses) ===")

        for _, cond in pairs(SUPPORTED_CONDITIONS) do
            local name = CONST.EnemyConditionTypeNames[cond]
            local config = theme.Condition.Conditions[name]

            local opened = imgui.tree_node(name)
            imgui.same_line()
            imgui.text(config.DisplayName)
            if not config.Enable then
                imgui.same_line()
                imgui.text(" -- Disabled --  ")
            end
            local condConfigChanged = false
            if opened then
                changed, config.Enable = imgui.checkbox("Enabled", config.Enable)
                condConfigChanged = condConfigChanged or changed

                changed, config.AlwaysShow = imgui.checkbox("Always Display (lower priority than OnlyInBattle/OnlyDamaged)", config.AlwaysShow)
                condConfigChanged = condConfigChanged or changed

                changed, config.DisplayName = imgui.input_text("Display Name", config.DisplayName)
                condConfigChanged = condConfigChanged or changed

                changed, config.UseDefaultFontStyle = imgui.checkbox("Use Default Font Style", config.UseDefaultFontStyle)
                condConfigChanged = condConfigChanged or changed
                if not config.UseDefaultFontStyle then
                    changed, config.FontStyle = Draw.FontConfigMenu(config.FontStyle, "Font Style")
                    condConfigChanged = condConfigChanged or changed
                end

                changed, config.UseDefaultRectStyle = imgui.checkbox("Use Default Bar Style", config.UseDefaultRectStyle)
                condConfigChanged = condConfigChanged or changed
                if not config.UseDefaultRectStyle then
                    changed, config.Rect = Draw.RectConfigMenu(config.Rect, "Bar Style")
                    condConfigChanged = condConfigChanged or changed
                end

                if condConfigChanged then
                    theme.Condition.Conditions[name] = config
                end
                imgui.tree_pop()
            end
            configChanged = configChanged or condConfigChanged
        end

        imgui.tree_pop()
    end

    if imgui.tree_node("Parts Options") then
        changed, theme.Part.Enable = imgui.checkbox("Enable", theme.Part.Enable)
        configChanged = configChanged or changed
        changed, theme.Part.Width = imgui.drag_int("Width", theme.Part.Width, 1, 0, w)
        configChanged = configChanged or changed
        changed, theme.Part.OffsetX = imgui.drag_int("OffsetX", theme.Part.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, theme.Part.OffsetY = imgui.drag_int("OffsetY", theme.Part.OffsetY, 1, -h, h)
        configChanged = configChanged or changed
    
        changed, theme.Part.Columns = imgui.slider_int("Columns", theme.Part.Columns, 0, 10)
        configChanged = configChanged or changed
        changed, theme.Part.ColumnMargin = imgui.slider_int("Column Margin", theme.Part.ColumnMargin, 0, 100)
        configChanged = configChanged or changed
        changed, theme.Part.RowMargin = imgui.slider_int("Row Margin", theme.Part.RowMargin, 0, 100)
        configChanged = configChanged or changed

        changed, theme.Part.OnlyInBattle = imgui.checkbox("Only In Battle", theme.Part.OnlyInBattle)
        configChanged = configChanged or changed

        changed, theme.Part.AlwaysShow = imgui.checkbox("Always Display (if not, auto hide full hp parts)", theme.Part.AlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Part.OnlyBreakable = imgui.checkbox("Only Breakable (including severable)", theme.Part.OnlyBreakable)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.BreakableAlwaysShow = imgui.checkbox("Always Display Breakable (follows only in battle)", theme.Part.BreakableAlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Part.OnlySeverable = imgui.checkbox("Only Severable", theme.Part.OnlySeverable)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.SeverableAlwaysShow = imgui.checkbox("Always Display Severable (follows only in battle)", theme.Part.SeverableAlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Part.BrokenNoAlwaysShow = imgui.checkbox("Don't Always Show if Breakable/Severable part has been broken", theme.Part.BrokenNoAlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Part.HideHigherThanMaxHpPart = imgui.checkbox("Hide Parts that HP higher than Monster Max HP", theme.Part.HideHigherThanMaxHpPart)
        configChanged = configChanged or changed

        changed, theme.Part.AutoHide = imgui.checkbox("Auto Hide", theme.Part.AutoHide)
        configChanged = configChanged or changed

        if theme.Part.AutoHide then
            changed, theme.Part.AutoHideSeconds = imgui.slider_float("Auto Hide Secs", theme.Part.AutoHideSeconds, 0, 60.0)
            configChanged = configChanged or changed
        end

        imgui.text("")
        imgui.text("=== Parts Global Style ===")

        changed, theme.Part.ShowPartName = imgui.checkbox("Show Part Name", theme.Part.ShowPartName)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.ShowPartLevel = imgui.checkbox("Show Part Level", theme.Part.ShowPartLevel)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.ShowPartHP = imgui.checkbox("Show Part HP", theme.Part.ShowPartHP)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.ShowPartMaxHP = imgui.checkbox("Show Part MaxHP", theme.Part.ShowPartMaxHP)
        configChanged = configChanged or changed
        
        changed, theme.Part.ShowBreakableIcon = imgui.checkbox("Show Breakable Icon", theme.Part.ShowBreakableIcon)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, theme.Part.ShowSeverableIcon = imgui.checkbox("Show Severable Icon", theme.Part.ShowSeverableIcon)
        configChanged = configChanged or changed
    
        changed, theme.Part.FontStyle = Draw.FontConfigMenu(theme.Part.FontStyle, "Part Name Style")
        configChanged = configChanged or changed

        changed, theme.Part.PartRect = Draw.RectConfigMenu(theme.Part.PartRect, "Part Bar Style")
        configChanged = configChanged or changed

        changed, theme.Part.ScarRing = Draw.CircleConfigMenu(theme.Part.ScarRing, "Part Scar Style")
        configChanged = configChanged or changed

        changed, theme.Part.ScarLevelText = Draw.FontConfigMenu(theme.Part.ScarLevelText, "Part Scar Text Style")
        configChanged = configChanged or changed

        changed, theme.Part.Scar.ShowRideScar = imgui.checkbox("Show Ride Scar", theme.Part.Scar.ShowRideScar)
        configChanged = configChanged or changed
        if theme.Part.Scar.ShowRideScar then
            imgui.same_line()
            changed, theme.Part.Scar.UseSpecialRideScarColor = imgui.checkbox("Use Special Ride Scar Color", theme.Part.Scar.UseSpecialRideScarColor)
            configChanged = configChanged or changed
        end
        
        changed, theme.Part.Scar.ShowLegendaryScar = imgui.checkbox("Show Legendary Scar", theme.Part.Scar.ShowLegendaryScar)
        configChanged = configChanged or changed
        if theme.Part.Scar.ShowLegendaryScar then
            imgui.same_line()
            changed, theme.Part.Scar.UseSpecialLegendaryScarColor = imgui.checkbox("Use Special Legendary Scar Color", theme.Part.Scar.UseSpecialLegendaryScarColor)
            configChanged = configChanged or changed
        end
        
        if imgui.tree_node("Scar Colors") then
            changed, theme.Part.Scar.NormalColor = imgui.color_picker("Normal Color", theme.Part.Scar.NormalColor)
            configChanged = configChanged or changed

            changed, theme.Part.Scar.TearColor = imgui.color_picker("Tear Color", theme.Part.Scar.TearColor)
            configChanged = configChanged or changed

            changed, theme.Part.Scar.RawColor = imgui.color_picker("Raw Color", theme.Part.Scar.RawColor)
            configChanged = configChanged or changed

            changed, theme.Part.Scar.RideColor = imgui.color_picker("Ride Color", theme.Part.Scar.RideColor)
            configChanged = configChanged or changed

            changed, theme.Part.Scar.LegendaryColor = imgui.color_picker("Legendary Color", theme.Part.Scar.LegendaryColor)
            configChanged = configChanged or changed

            imgui.tree_pop()
        end

        imgui.text("")
        imgui.text("=== Parts Style ===")

        changed, theme.Part.MenuOptionsShowOnlyCurrentTarget = imgui.checkbox("Show only current target", theme.Part.MenuOptionsShowOnlyCurrentTarget)
        configChanged = configChanged or changed

        local CurrentQuestParts = {}
        if theme.Part.MenuOptionsShowOnlyCurrentTarget then
            local browsers = Core.GetMissionManager():getAcceptQuestTargetBrowsers()
            if browsers ~= nil then
                Core.ForEach(browsers, function (browser)
                    local ctx = browser:get_EmContext()
                    local options = GetEnemyLegalOptions(ctx)
                    for part, value in pairs(options) do
                        CurrentQuestParts[part] = value
                    end
                end)
            end
        end

        for _, part in pairs(SUPPORTED_PARTS) do
            if theme.Part.MenuOptionsShowOnlyCurrentTarget then
                if not CurrentQuestParts[part] then
                    goto continue
                end
            end

            local name = CONST.EnemyPartsTypeNames[part]
            local config = theme.Part.Parts[name]

            local opened = imgui.tree_node(name)
            imgui.same_line()
            imgui.text(config.DisplayName)
            if not config.Enable then
                imgui.same_line()
                imgui.text(" -- Disabled --  ")
            end
            local partConfChanged = false
            if opened then
                changed, config.Enable = imgui.checkbox("Enabled", config.Enable)
                partConfChanged = partConfChanged or changed

                changed, config.AlwaysShow = imgui.checkbox("Always Display (lower priority than OnlyInBattle/OnlyDamaged)", config.AlwaysShow)
                partConfChanged = partConfChanged or changed

                changed, config.DisplayName = imgui.input_text("Display Name", config.DisplayName)
                partConfChanged = partConfChanged or changed

                changed, config.UseDefaultFontStyle = imgui.checkbox("Use Default Font Style", config.UseDefaultFontStyle)
                partConfChanged = partConfChanged or changed
                if not config.UseDefaultFontStyle then
                    changed, config.FontStyle = Draw.FontConfigMenu(config.FontStyle, "Font Style")
                    partConfChanged = partConfChanged or changed
                end

                changed, config.UseDefaultPartStyle = imgui.checkbox("Use Default Bar Style", config.UseDefaultPartStyle)
                partConfChanged = partConfChanged or changed
                if not config.UseDefaultPartStyle then
                    changed, config.Rect = Draw.RectConfigMenu(config.Rect, "Bar Style")
                    partConfChanged = partConfChanged or changed
                end

                changed, config.UseDefaultScarStyle = imgui.checkbox("Use Default Scar Style", config.UseDefaultScarStyle)
                partConfChanged = partConfChanged or changed
                if not config.UseDefaultScarStyle then
                    changed, config.ScarRing = Draw.CircleConfigMenu(config.ScarRing, "Scar Style")
                    partConfChanged = partConfChanged or changed
                    
                    changed, config.Scar.ShowRideScar = imgui.checkbox("Show Ride Scar", config.Scar.ShowRideScar)
                    configChanged = configChanged or changed
                    if config.Scar.ShowRideScar then
                        imgui.same_line()
                        changed, config.Scar.UseSpecialRideScarColor = imgui.checkbox("Use Special Ride Scar Color", config.Scar.UseSpecialRideScarColor)
                        configChanged = configChanged or changed
                    end
                    
                    changed, config.Scar.ShowLegendaryScar = imgui.checkbox("Show Legendary Scar", config.Scar.ShowLegendaryScar)
                    configChanged = configChanged or changed
                    if config.Scar.ShowLegendaryScar then
                        imgui.same_line()
                        changed, config.Scar.UseSpecialLegendaryScarColor = imgui.checkbox("Use Special Legendary Scar Color", config.Scar.UseSpecialLegendaryScarColor)
                        configChanged = configChanged or changed
                    end

                    if imgui.tree_node("Scar Colors") then
                        changed, config.Scar.NormalColor = imgui.color_picker("Normal Color", config.Scar.NormalColor)
                        partConfChanged = partConfChanged or changed

                        changed, config.Scar.TearColor = imgui.color_picker("Tear Color", config.Scar.TearColor)
                        partConfChanged = partConfChanged or changed

                        changed, config.Scar.RawColor = imgui.color_picker("Raw Color", config.Scar.RawColor)
                        partConfChanged = partConfChanged or changed

                        changed, config.Scar.RideColor = imgui.color_picker("Ride Color", config.Scar.RideColor)
                        partConfChanged = partConfChanged or changed

                        changed, config.Scar.LegendaryColor = imgui.color_picker("Legendary Color", config.Scar.LegendaryColor)
                        partConfChanged = partConfChanged or changed

                        imgui.tree_pop()
                    end
                end

                changed, config.UseDefaultScarLevelFontStyle = imgui.checkbox("Use Default Scar Text Style", config.UseDefaultScarLevelFontStyle)
                partConfChanged = partConfChanged or changed
                if not config.UseDefaultScarLevelFontStyle then
                    changed, config.ScarLevelText = Draw.FontConfigMenu(config.ScarLevelText, "Scar Text Style")
                    partConfChanged = partConfChanged or changed
                end

                if partConfChanged then
                    theme.Part.Parts[name] = config
                end
                imgui.tree_pop()
            end

            configChanged = configChanged or partConfChanged
            ::continue::
        end

        imgui.tree_pop()
    end

    if imgui.tree_node("Scars Options") then
        changed, theme.Scar.Enable = imgui.checkbox("Enable", theme.Scar.Enable)
        configChanged = configChanged or changed
    
        changed, theme.Scar.Width = imgui.drag_int("Width", theme.Scar.Width, 1, 0, w)
        configChanged = configChanged or changed
        changed, theme.Scar.Height = imgui.slider_int("Height", theme.Scar.Height, 0, 100)
        configChanged = configChanged or changed
        changed, theme.Scar.OffsetX = imgui.drag_int("OffsetX", theme.Scar.OffsetX, 1, -w, w)
        configChanged = configChanged or changed
        changed, theme.Scar.OffsetY = imgui.drag_int("OffsetY", theme.Scar.OffsetY, 1, -h, h)
        configChanged = configChanged or changed
    
        changed, theme.Scar.Columns = imgui.slider_int("Columns", theme.Scar.Columns, 0, 10)
        configChanged = configChanged or changed

        changed, theme.Scar.ColumnMargin = imgui.slider_int("Column Margin", theme.Scar.ColumnMargin, 0, 100)
        configChanged = configChanged or changed

        changed, theme.Scar.RowMargin = imgui.slider_int("Row Margin", theme.Scar.RowMargin, 0, 100)
        configChanged = configChanged or changed

        changed, theme.Scar.OnlyInBattle = imgui.checkbox("Only In Battle", theme.Scar.OnlyInBattle)
        configChanged = configChanged or changed

        changed, theme.Scar.AlwaysShow = imgui.checkbox("Always Display (if not, auto hide full hp parts)", theme.Scar.AlwaysShow)
        configChanged = configChanged or changed

        changed, theme.Scar.AutoHide = imgui.checkbox("Auto Hide", theme.Scar.AutoHide)
        configChanged = configChanged or changed

        if theme.Scar.AutoHide then
            changed, theme.Scar.AutoHideSeconds = imgui.slider_float("Auto Hide Secs", theme.Scar.AutoHideSeconds, 0, 60.0)
            configChanged = configChanged or changed
        end

        changed, theme.Scar.ScarRect = Draw.RectConfigMenu(theme.Scar.ScarRect, "Scar Bar Style")
        configChanged = configChanged or changed
    
        changed, theme.Scar.FontStyle = Draw.FontConfigMenu(theme.Scar.FontStyle, "Scar Text Style")
        configChanged = configChanged or changed
    
        changed, theme.Scar.ShowPartName = imgui.checkbox("Show Part Name", theme.Scar.ShowPartName)
        configChanged = configChanged or changed
        changed, theme.Scar.ShowScarLevel = imgui.checkbox("Show Scar Level", theme.Scar.ShowScarLevel)
        configChanged = configChanged or changed
        changed, theme.Scar.ShowScarIndex = imgui.checkbox("Show Scar Index", theme.Scar.ShowScarIndex)
        configChanged = configChanged or changed
        changed, theme.Scar.ShowScarHP = imgui.checkbox("Show Scar HP", theme.Scar.ShowScarHP)
        configChanged = configChanged or changed
        changed, theme.Scar.ShowScarMaxHP = imgui.checkbox("Show Scar Max HP", theme.Scar.ShowScarMaxHP)
        configChanged = configChanged or changed
    
        changed, theme.Scar.ScarColors.ShowRideScar = imgui.checkbox("Show Ride Scar", theme.Scar.ScarColors.ShowRideScar)
        configChanged = configChanged or changed
        if theme.Scar.ScarColors.ShowRideScar then
            imgui.same_line()
            changed, theme.Scar.ScarColors.UseSpecialRideScarColor = imgui.checkbox("Use Special Ride Scar Color", theme.Scar.ScarColors.UseSpecialRideScarColor)
            configChanged = configChanged or changed
        end
        
        changed, theme.Scar.ScarColors.ShowLegendaryScar = imgui.checkbox("Show Legendary Scar", theme.Scar.ScarColors.ShowLegendaryScar)
        configChanged = configChanged or changed
        if theme.Scar.ScarColors.ShowLegendaryScar then
            imgui.same_line()
            changed, theme.Scar.ScarColors.UseSpecialLegendaryScarColor = imgui.checkbox("Use Special Legendary Scar Color", theme.Scar.ScarColors.UseSpecialLegendaryScarColor)
            configChanged = configChanged or changed
        end

        if imgui.tree_node("Scar Colors") then
            changed, theme.Scar.ScarColors.NormalColor = imgui.color_picker("Normal Color", theme.Scar.ScarColors.NormalColor)
            configChanged = configChanged or changed

            changed, theme.Scar.ScarColors.TearColor = imgui.color_picker("Tear Color", theme.Scar.ScarColors.TearColor)
            configChanged = configChanged or changed

            changed, theme.Scar.ScarColors.RawColor = imgui.color_picker("Raw Color", theme.Scar.ScarColors.RawColor)
            configChanged = configChanged or changed

            changed, theme.Scar.ScarColors.RideColor = imgui.color_picker("Ride Color", theme.Scar.ScarColors.RideColor)
            configChanged = configChanged or changed

            changed, theme.Scar.ScarColors.LegendaryColor = imgui.color_picker("Legendary Color", theme.Scar.ScarColors.LegendaryColor)
            configChanged = configChanged or changed

            imgui.tree_pop()
        end

        imgui.tree_pop()
    end

    if configChanged then
        mod.Runtime.Themes[Config.ThemeIndex] = theme
        if Config.ThemeIndex == 1 then
            ThemeStylized = theme
            mod.SaveConfig(CONF_STYLIZED, theme)
        elseif Config.ThemeIndex == 2 then
            ThemeNormal = theme
            mod.SaveConfig(CONF_NORMAL, theme)
        elseif Config.ThemeIndex == 3 then
            ThemeCustom = theme
            mod.SaveConfig(CONF_CUSTOM, theme)
        end
    end
    return configChanged
end)

return Config
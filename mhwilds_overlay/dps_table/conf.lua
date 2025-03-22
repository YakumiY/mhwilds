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

local Config = mod.Config.StatTableConfig

local InitialDisabledColumn = {
    ["fDPS"] = true,
    ["qDPS"] = true,
    ["Physical"] = true,
    ["Elemental"] = true,
    ["FixedDamage"] = true,
    ["PoisonDamage"] = true,
    ["BlastDamage"] = true,
    ["PhysicalPercentage"] = true,
    ["ElementalPercentage"] = true,
    ["FixedDamagePercentage"] = true,
    ["PoisonDamagePercentage"] = true,
    ["BlastDamagePercentage"] = true,

    ["StatusPercentage"] = true,

    ["FightingTime"] = true,
    ["HitCount"] = true,
    ["CriticalCount"] = true,
    ["NegativeCriticalCount"] = true,
    ["NegativeCriticalCountPercentage"] = true,

    ["StaminaPercentage"] = true,
    ["StunPercentage"] = true,
    ["PoisonPercentage"] = true,
    ["ParalysePercentage"] = true,
    ["SleepPercentage"] = true,
    ["BlastPercentage"] = true,
    
    ["RidePercentage"] = true,
    ["BlockPercentage"] = true,
    ["ParryPercentage"] = true,

    ["SkillStabbingPercentage"] = true,

    ["RealDamage"] = true,
}

local SupportedColumn = {
    "HR",
    "Name", "DPS", "fDPS", "qDPS",
    "Damage", "DamagePercentage",
    "Physical", "PhysicalPercentage", "SelfPhysicalPercentage",
    "Elemental", "ElementalPercentage", "SelfElementalPercentage",
    "FixedDamage", "FixedDamagePercentage", "SelfFixedDamagePercentage",
    "PoisonDamage", "PoisonDamagePercentage", "SelfPoisonDamagePercentage",
    "BlastDamage", "BlastDamagePercentage", "SelfBlastDamagePercentage",
    "StabbingDamage", "SelfStabbingDamagePercentage",

    "FightingTime",

    "HitCount",
    "SoftHitCount", "SoftHitCountPercentage",
    "ElementalSoftHitCount", "ElementalSoftHitCountPercentage",
    "CriticalCount", "CriticalCountPercentage",
    "NegativeCriticalCount","NegativeCriticalCountPercentage",

    "Status", "StatusPercentage",

    "Stamina", "StaminaPercentage",
    "Stun", "StunPercentage",
    "Poison", "PoisonPercentage",
    "Paralyse", "ParalysePercentage",
    "Sleep", "SleepPercentage",
    "Blast", "BlastPercentage",

    "Ride", "RidePercentage",
    "Block", "BlockPercentage",
    "Parry", "ParryPercentage",
    
    "SkillStabbing", "SkillStabbingPercentage",

    "RealDamage",
}

local SupportedColumnName = {
    ["HR"] = "HR",
    ["Name"] = "Name",
    ["DPS"] = "DPS",
    ["fDPS"] = "fDPS",
    ["qDPS"] = "qDPS",
    ["Damage"] = "Damage",
    ["DamagePercentage"] = "Party%",
    ["Physical"] = "Physical",
    ["PhysicalPercentage"] = "Phys.Party%",
    ["SelfPhysicalPercentage"] = "Phys.%",
    ["Elemental"] = "Elemental",
    ["ElementalPercentage"] = "Ele.Party%",
    ["SelfElementalPercentage"] = "Ele.%",
    ["FixedDamage"] = "Fixed",
    ["FixedDamagePercentage"] = "Fix.Party%",
    ["SelfFixedDamagePercentage"] = "Fix.%",
    ["PoisonDamage"] = "Poison.Dmg",
    ["PoisonDamagePercentage"] = "P.Dmg.Party%",
    ["SelfPoisonDamagePercentage"] = "P.Dmg.%",
    ["BlastDamage"] = "Blast.Dmg",
    ["BlastDamagePercentage"] = "B.Dmg.Party%",
    ["StabbingDamage"] = "Flayer.Dmg",
    ["SelfStabbingDamagePercentage"] = "F.Dmg%",
    ["SelfBlastDamagePercentage"] = "B.Dmg%",
    ["FightingTime"] = "Time",
    ["HitCount"] = "HitCount",
    ["CriticalCount"] = "CritCount",
    ["CriticalCountPercentage"] = "Crit%",
    ["NegativeCriticalCount"] = "NegCrit",
    ["NegativeCriticalCountPercentage"] = "NegCrit%",
    ["SoftHitCount"] = "Soft",
    ["SoftHitCountPercentage"] = "Soft%",
    ["ElementalSoftHitCount"] = "Ele.Soft",
    ["ElementalSoftHitCountPercentage"] = "Ele.Soft%",

    ["Status"] = "Status",
    ["StatusPercentage"] = "Status%",
    ["Stun"] = "Stun",
    ["Ride"] = "Ride",
    ["Block"] = "Block",
    ["Parry"] = "Parry",
    ["Poison"] = "Poison",
    ["Paralyse"] = "Paralyse",
    ["Sleep"] = "Sleep",
    ["Blast"] = "Blast",
    ["Stamina"] = "Stamina",
    ["SkillStabbing"] = "Flayer",

    ["StunPercentage"] = "Stun%",
    ["RidePercentage"] = "Ride%",
    ["BlockPercentage"] = "Block%",
    ["ParryPercentage"] = "Parry%",
    ["PoisonPercentage"] = "Poison%",
    ["ParalysePercentage"] = "Paralyse%",
    ["SleepPercentage"] = "Sleep%",
    ["BlastPercentage"] = "Blast%",
    ["StaminaPercentage"] = "Stamina%",
    ["SkillStabbingPercentage"] = "Flayer%",

    ["RealDamage"] = "R.Damage",
}

local function NewTableColumnConfig(key, i)
    local conf = {
        Enable = true,
        AutoHideZeroStatusColumns = true,
        AutoColumnWidth = true,
        Width = 0,

        Header = {
            Enable = true,
            UseBackground = false,
            BackgroundColor = 0x90000000,
            
            Abosulte = true,
            BlockRenderX = false,
            BlockRenderY = true,
            BlockReserveY = true,
        },
        Row = {
            Enable = true,
            UseBackground = false,
            BackgroundColor = 0x90000000,
            
            Abosulte = true,
            BlockRenderX = false,
            BlockRenderY = true,
            BlockReserveY = true,
        },

        ColumnKey = key,
        Name = SupportedColumnName[key],
        Order = i,
        Index = i,
    }
    if InitialDisabledColumn[key] then
        conf.Enable = false
    end
    return conf
end

local function NewDefaultConfig()
    local DefaultConfig = {
        Enable = true,
        HideOthers = false,

        PosX = ScreenWidth*0.25,
        PosY = 0,
        QuestInfo = {
            Enable = true,
            QuestTime = true,
            QuestTargets = true,
            Height = 32 *Scale,
            AutoHeight = true,

            FontConfig = {
                Absolute = true,
            },
            Background = {
                Enable = false,
                Absolute = true,
                BlockRenderX = false,
                BlockRenderY = true,

                UseBackground = true,
                BackgroundColor = 0x90000000,
            },
        },

        Header = {
            Enable = true,
            Height = 28 *Scale,
            AutoHeight = true,
            
            FontConfig = Draw.DefaultFontConfig({
                Absolute = true,
                BlockRenderX = true,
                BlockRenderY = true,
            }),
            Background = {
                Enable = false,
                Absolute = true,
                BlockRenderX = false,
                BlockRenderY = true,

                UseBackground = true,
                BackgroundColor = 0x90000000,
            },
        },
        Row = {
            Enable = true,
            Height = 28 *Scale,
            AutoHeight = true,
            Sort = true,
            
            FontConfig = Draw.DefaultFontConfig({
                Absolute = true,
                BlockRenderX = false,
                BlockRenderY = true,
            }),
            Background = {
                Enable = false,
                Absolute = true,
                BlockRenderX = false,
                BlockRenderY = true,

                UseBackground = true,
                BackgroundColor = 0x90000000,
            },
        },

        Column = {
            Enable = true,
            AutoHideZeroStatusColumns = true,
            AutoColumnWidth = true,
            Width = 70 *Scale,
            Columns = {}
        },
    
        DPSLine = {
            Enable = true,

            AutoWidth = true,
            AutoHeight = true,
            WidthAffectedByRatio = true,
        
            Width = 0,
            Height = 28 *Scale,
            OffsetX = 0,
            OffsetY = 0,

            DPSHighestFull = false,
            FillKeys = {
                {
                    Key = "Physical",
                    Colors = {
                        ["0"] = (Draw.ReverseRGB(0x4400FF00)),
                        ["1"] = (Draw.ReverseRGB(0x44FF0000)),
                        ["2"] = (Draw.ReverseRGB(0x44FFFF00)),
                        ["3"] = (Draw.ReverseRGB(0x4400FFFF)),
                        ["4"] = (Draw.ReverseRGB(0x44FF00FF)),
                        Others = Draw.ReverseRGB(0x8800FFFF),
                    },
                },
                {
                    Key = "Elemental",
                    Colors = {
                        ["0"] = Draw.DarkenRGB(Draw.ReverseRGB(0x4400FF00), 0.5),
                        ["1"] = Draw.DarkenRGB(Draw.ReverseRGB(0x44FF0000), 0.5),
                        ["2"] = Draw.DarkenRGB(Draw.ReverseRGB(0x44FFFF00), 0.5),
                        ["3"] = Draw.DarkenRGB(Draw.ReverseRGB(0x4400FFFF), 0.5),
                        ["4"] = Draw.DarkenRGB(Draw.ReverseRGB(0x44FF00FF), 0.5),
                        Others = Draw.DarkenRGB(Draw.ReverseRGB(0x8800FFFF), 0.5),
                    },
                },
                {
                    Key = "Fixed",
                    Colors = {
                        ["0"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                        ["1"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                        ["2"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                        ["3"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                        ["4"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                        Others = Draw.DarkenRGB(Draw.ReverseRGB(0x88DDDDDD), 0.5),
                    },
                },
                {
                    Key = "PoisonDamage",
                    Colors = {
                        ["0"] = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                        ["1"] = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                        ["2"] = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                        ["3"] = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                        ["4"] = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                        Others = Draw.DarkenRGB(Draw.ReverseRGB(0x887607EA), 0.5),
                    },
                },
                {
                    Key = "BlastDamage",
                    Colors = {
                        ["0"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                        ["1"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                        ["2"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                        ["3"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                        ["4"] = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                        Others = Draw.DarkenRGB(Draw.ReverseRGB(0x88EA700D), 0.5),
                    },
                },
            },
        },
    }

    for k, v in pairs(SupportedColumn) do
        if DefaultConfig.Column.Columns[k] == nil then
            DefaultConfig.Column.Columns[k] = NewTableColumnConfig(v, k)
        end
    end
    return DefaultConfig    
end

local function BuildSortedColumns(Config)
    local array = {}
    
    for k, v in pairs(Config.Column.Columns) do
        array[k] = v
    end

    table.sort(array, function (a, b)
        if a.Order == b.Order then
            return a.Index < b.Index
        end
        return a.Order < b.Order
    end)

    mod.Runtime.StatTableColumns = array
end

local function InitConfigurations(Config)
    Scale = LibConf.UIScale
    Config = Utils.MergeTablesRecursive(NewDefaultConfig(), Config)
    mod.Config.StatTableConfig = Config
    mod.SaveConfig()

    BuildSortedColumns(Config)
    mod.Runtime.StatsConfig = Config
    return Config
end

Config = InitConfigurations(Config)

local w, h = ScreenWidth, ScreenHeight

mod.SubMenu("Stats Table Options", function ()
	local configChanged = false
    local changed = false

    if imgui.button("Regenerate Config") then
        Config = InitConfigurations()
    end
    
    changed, Config.Enable = imgui.checkbox("Enable", Config.Enable)
    configChanged = configChanged or changed
    
    changed, Config.HideOthers = imgui.checkbox("HideOthers", Config.HideOthers)
    configChanged = configChanged or changed

    changed, Config.PosX = imgui.slider_int("Pos X", Config.PosX, 0, w)
    configChanged = configChanged or changed
    changed, Config.PosY = imgui.slider_int("Pos Y", Config.PosY, 0, h)
    configChanged = configChanged or changed

    if imgui.tree_node("Quest Info Options") then
        local cfg = Config.QuestInfo
        changed, cfg.Enable = imgui.checkbox("Enable", cfg.Enable)
        configChanged = configChanged or changed

        changed, cfg.QuestTime = imgui.checkbox("Enable QuestTime", cfg.QuestTime)
        configChanged = configChanged or changed

        changed, cfg.QuestTargets = imgui.checkbox("Enable QuestTargets", cfg.QuestTargets)
        configChanged = configChanged or changed

        changed, cfg.AutoHeight = imgui.checkbox("Auto Height", cfg.AutoHeight)
        configChanged = configChanged or changed

        if not cfg.AutoHeight then
            changed, cfg.Height = imgui.drag_int("Height", cfg.Height, 1, 1, h)
            configChanged = configChanged or changed
        end

        changed, cfg.FontConfig = Draw.FontConfigMenu(cfg.FontConfig, "Font Style")
        configChanged = configChanged or changed

        changed, cfg.Background = Draw.RectConfigMenu(cfg.Background, "Background Style")
        configChanged = configChanged or changed

        if configChanged then
            Config.QuestInfo = cfg
        end

        imgui.tree_pop()
    end

    if imgui.tree_node("Table Header Options") then
        local cfg = Config.Header
        changed, cfg.Enable = imgui.checkbox("Enable", cfg.Enable)
        configChanged = configChanged or changed

        changed, cfg.AutoHeight = imgui.checkbox("Auto Height", cfg.AutoHeight)
        configChanged = configChanged or changed

        if not cfg.AutoHeight then
            changed, cfg.Height = imgui.drag_int("Height", cfg.Height, 1, 1, h)
            configChanged = configChanged or changed
        end

        changed, cfg.FontConfig = Draw.FontConfigMenu(cfg.FontConfig, "Font Style")
        configChanged = configChanged or changed

        changed, cfg.Background = Draw.RectConfigMenu(cfg.Background, "Background Style")
        configChanged = configChanged or changed

        if configChanged then
            Config.Header = cfg
        end
        imgui.tree_pop()
    end
    if imgui.tree_node("Table Row Options") then
        local cfg = Config.Row
        changed, cfg.Enable = imgui.checkbox("Enable", cfg.Enable)
        configChanged = configChanged or changed

        changed, cfg.AutoHeight = imgui.checkbox("Auto Height", cfg.AutoHeight)
        configChanged = configChanged or changed

        if not cfg.AutoHeight then
            changed, cfg.Height = imgui.drag_int("Height", cfg.Height, 1, 1, h)
            configChanged = configChanged or changed
        end

        changed, cfg.FontConfig = Draw.FontConfigMenu(cfg.FontConfig, "Font Style")
        configChanged = configChanged or changed

        changed, cfg.Background = Draw.RectConfigMenu(cfg.Background, "Background Style")
        configChanged = configChanged or changed

        if configChanged then
            Config.Row = cfg
        end
        imgui.tree_pop()
    end

    if imgui.tree_node("Fill Color Options") then
        local cfg = Config.DPSLine

        changed, cfg.Enable = imgui.checkbox("Enable", cfg.Enable)
        configChanged = configChanged or changed

        changed, cfg.AutoHeight = imgui.checkbox("Auto Height", cfg.AutoHeight)
        configChanged = configChanged or changed

        changed, cfg.AutoWidth = imgui.checkbox("Auto Width", cfg.AutoWidth)
        configChanged = configChanged or changed

        changed, cfg.WidthAffectedByRatio = imgui.checkbox("Auto Width by Party Ratio", cfg.WidthAffectedByRatio)
        configChanged = configChanged or changed

        changed, cfg.DPSHighestFull = imgui.checkbox("Highest Fill Row as 100%", cfg.DPSHighestFull)
        configChanged = configChanged or changed

        if not cfg.AutoHeight then
            changed, cfg.Height = imgui.drag_int("Height", cfg.Height, 1, 0, h)
            configChanged = configChanged or changed
        end
        if not cfg.AutoWidth then
            changed, cfg.Width = imgui.drag_int("Width", cfg.Width, 1, 0, w)
            configChanged = configChanged or changed
        end
        changed, cfg.OffsetX = imgui.drag_int("OffsetX", cfg.OffsetX, 1, 0, h)
        configChanged = configChanged or changed
        changed, cfg.OffsetY = imgui.drag_int("OffsetY", cfg.OffsetY, 1, 0, h)
        configChanged = configChanged or changed

    
        if imgui.tree_node("Colors Options") then
            for i = 0, 3, 1 do
                local key = tostring(i)
                if imgui.tree_node(string.format("P%d Colors", i+1)) then
                    changed, cfg.FillKeys[1].Colors[key] = imgui.color_picker("Physical Color",cfg.FillKeys[1].Colors[key])
                    configChanged = configChanged or changed
                
                    changed, cfg.FillKeys[2].Colors[key] = imgui.color_picker("Elemental Color", cfg.FillKeys[2].Colors[key])
                    configChanged = configChanged or changed
    
                    changed, cfg.FillKeys[3].Colors[key] = imgui.color_picker("Fixed Color", cfg.FillKeys[3].Colors[key])
                    configChanged = configChanged or changed
    
                    changed, cfg.FillKeys[4].Colors[key] = imgui.color_picker("Poison Color", cfg.FillKeys[4].Colors[key])
                    configChanged = configChanged or changed
    
                    changed, cfg.FillKeys[5].Colors[key] = imgui.color_picker("Blast Color", cfg.FillKeys[5].Colors[key])
                    configChanged = configChanged or changed
    
                    imgui.tree_pop()
                end
            end
        
            if imgui.tree_node("Others Colors") then
                changed, cfg.FillKeys[1].Colors.Others = imgui.color_picker("Physical Color",cfg.FillKeys[1].Colors.Others)
                configChanged = configChanged or changed
            
                changed, cfg.FillKeys[2].Colors.Others = imgui.color_picker("Elemental Color", cfg.FillKeys[2].Colors.Others)
                configChanged = configChanged or changed

                changed, cfg.FillKeys[3].Colors.Others = imgui.color_picker("Fixed Color", cfg.FillKeys[3].Colors.Others)
                configChanged = configChanged or changed

                changed, cfg.FillKeys[4].Colors.Others = imgui.color_picker("Poison Color", cfg.FillKeys[4].Colors.Others)
                configChanged = configChanged or changed

                changed, cfg.FillKeys[5].Colors.Others = imgui.color_picker("Blast Color", cfg.FillKeys[5].Colors.Others)
                configChanged = configChanged or changed

                imgui.tree_pop()
            end

            imgui.tree_pop()
        end
    

        if configChanged then
            Config.DPSLine = cfg
        end
        imgui.tree_pop()
    end

    if imgui.tree_node("Columns Options") then
        local cfg = Config.Column

        changed, cfg.AutoHideZeroStatusColumns = imgui.checkbox("Auto Hide Zero Value Columns", cfg.AutoHideZeroStatusColumns)
        configChanged = configChanged or changed

        changed, cfg.AutoColumnWidth = imgui.checkbox("Auto Column Width", cfg.AutoColumnWidth)
        configChanged = configChanged or changed

        if not cfg.AutoColumnWidth then
            changed, cfg.Width = imgui.drag_int("Column Width", cfg.Width, 1, 0, h)
            configChanged = configChanged or changed
        end

        for k, v in pairs(cfg.Columns) do
            local opened = imgui.tree_node(string.format("##ColumnKey%s", tostring(k)))
            imgui.same_line()
            imgui.text(string.format("%s", v.Name))
            if not cfg.Columns[k].Enable then
                imgui.same_line()
                imgui.text(" -- Disabled --  ")
            end
            if opened then
                changed, cfg.Columns[k].Enable = imgui.checkbox("Enable", v.Enable)
                configChanged = configChanged or changed

                changed, cfg.Columns[k].Name = imgui.input_text("Display Name", v.Name)
                configChanged = configChanged or changed

                changed, cfg.Columns[k].Order = imgui.slider_int("Order", v.Order, 0, 50)
                configChanged = configChanged or changed
                if changed then
                    BuildSortedColumns(Config)
                end

                changed, cfg.Columns[k].AutoHideZeroStatusColumns = imgui.checkbox("Auto Hide If Zero Value", v.AutoHideZeroStatusColumns)
                configChanged = configChanged or changed
        
                changed, cfg.Columns[k].AutoColumnWidth = imgui.checkbox("Auto Width", v.AutoColumnWidth)
                configChanged = configChanged or changed
        
                if not cfg.Columns[k].AutoColumnWidth then
                    changed, cfg.Columns[k].Width = imgui.drag_int("Width", v.Width, 1, 0, h)
                    configChanged = configChanged or changed
                end

                changed, cfg.Columns[k].Header = Draw.RectConfigMenu(v.Header, "Header Options", true)
                configChanged = configChanged or changed

                changed, cfg.Columns[k].Row = Draw.RectConfigMenu(v.Row, "Row Options", true)
                configChanged = configChanged or changed

                imgui.tree_pop()
            end
        end

        if configChanged then
            Config.Column = cfg
        end
        imgui.tree_pop()
    end
    if configChanged then
        mod.Config.StatTableConfig = Config
    end

    return configChanged
end)

return Config
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

local Config = mod.Config.ShowAllHpConfig

local ScreenWidth, ScreenHeight = Core.GetScreenSize()
local DefaultWidth = ScreenWidth*0.15

local function NewEnemyTypeConfig(complex)
    local conf = OverlayDrawHpConf.NewDefaultTheme()
    conf.Enable = true
    conf.ValidFilter = true
    conf.HideDead = true

    conf.Header.ShowWeaknessIcon = false
    conf.Header.ShowSmallIcon = false
    if not complex then
        -- conf.Header.ShowCrownIcon = false
        conf.Header.Action = nil
        conf.Header.QuestTime = nil
        conf.Stamina = nil
        conf.Angry = nil
        -- conf.RedHp = nil
        conf.HpSegement = nil

        conf.SimpleMode = true
    else
        conf.Stamina.Width = 200 *Scale
        conf.Stamina.Height = 4 *Scale
        conf.Stamina.OutlineThickness = 1
        conf.Stamina.OutlineColor = 0xCC000000
        conf.Angry.Width = 200 *Scale
        conf.Angry.Height = 4 *Scale
        conf.Angry.OutlineThickness = 1
        conf.Angry.OutlineColor = 0xCC000000
        conf.Header.Action.Enable = false

        conf.SimpleMode = false
    end

    conf.Header.OffsetX = 0
    conf.Header.OffsetY = 0
    conf.Hp.Width = 200 *Scale
    conf.Hp.Height = 12 *Scale
    conf.Hp.OutlineThickness = 1
    conf.Hp.OutlineColor = 0xCC000000

    conf.FontSize = 18 *Scale
    conf.FontColor = 0xFFFFFFFF
    conf.Width = 200 *Scale
    conf.Height = 12 *Scale
    conf.OutlineColor = 0xFF000000
    conf.BackgroundColor = 0xFFAEAEAE
    conf.Color = Draw.ReverseRGB(0xFF76DCA7)

    return conf
end

local function NewDefaultConfig()
    local defaultConfig = {
        Enable = false,

        EnableDistanceLimit = true,
        MaxDistance = 500.0,

        EnableAlpha = true,
        AlphaStartDistance = 30,
        MinimalAlpha = 0.2,

        SimpleMode = true,
        FontSize = 18 *Scale,
        FontColor = 0xFFFFFFFF,
        Width = 200 *Scale,
        Height = 12 *Scale,
        OutlineColor = 0xFF000000,
        BackgroundColor = 0xFFAEAEAE,
        Color = Draw.ReverseRGB(0xFF76DCA7),

        Zako = NewEnemyTypeConfig(false),
        Animal = NewEnemyTypeConfig(false),
        Boss = NewEnemyTypeConfig(true),
        Other = NewEnemyTypeConfig(false),
    }
    -- defaultConfig.Zako.Enable = false
    -- defaultConfig.Animal.Enable = false

    return defaultConfig
end

local function InitConfigurations()
    Config = Utils.MergeTablesRecursive(NewDefaultConfig(), Config)
    mod.Config.ShowAllHpConfig = Config
    mod.SaveConfig()
end

InitConfigurations()

local w, h = ScreenWidth, ScreenHeight
local function EnemyTypeConfigMenu(tag, conf, simpleMode)
	local configChanged = false
    local changed = false
    
    Imgui.Tree(tag, function ()
        changed, conf.Enable = imgui.checkbox("Enable", conf.Enable)
        configChanged = configChanged or changed

        -- changed, conf.ValidFilter = imgui.checkbox("Valid Filter", conf.ValidFilter)
        -- configChanged = configChanged or changed

        changed, conf.HideDead = imgui.checkbox("Hide Dead", conf.HideDead)
        configChanged = configChanged or changed

        changed, conf.SimpleMode = imgui.checkbox("Simple Mode", conf.SimpleMode)
        configChanged = configChanged or changed
        if conf.SimpleMode then
            changed, conf.Width = imgui.drag_float("Width", conf.Width, 1, -w, w)
            configChanged = configChanged or changed
            changed, conf.Height = imgui.drag_float("height", conf.Height, 1, -h, h)
            configChanged = configChanged or changed
            
            changed, conf.FontSize = imgui.slider_int("Font Size", conf.FontSize, 1, 40)
            configChanged = configChanged or changed
            changed, conf.FontColor = imgui.color_picker("Font Color", conf.FontColor)
            configChanged = configChanged or changed
            changed, conf.Color = imgui.color_picker("Color", conf.Color)
            configChanged = configChanged or changed
            changed, conf.BackgroundColor = imgui.color_picker("BackgroundColor", conf.BackgroundColor)
            configChanged = configChanged or changed
            changed, conf.OutlineColor = imgui.color_picker("OutlineColor", conf.OutlineColor)
            configChanged = configChanged or changed
        else
            changed, conf = OverlayDrawHpConf.ThemeMenu("HP Widget Options", conf)
            configChanged = configChanged or changed
        end
    end)

    return configChanged, conf
end

mod.SubMenu("Show All HP", function()
	local configChanged = false
    local changed = false

    changed, Config.Enable = imgui.checkbox("Enable", Config.Enable)
    configChanged = configChanged or changed


    changed, Config.EnableAlpha = imgui.checkbox("Enable Alpha (SimpleMode only)", Config.EnableAlpha)
    configChanged = configChanged or changed
    if Config.EnableAlpha then
        changed, Config.AlphaStartDistance = imgui.drag_float("Alpha Start Distance", Config.AlphaStartDistance, 0.1, -1, Config.MaxDistance)
        configChanged = configChanged or changed
        changed, Config.MinimalAlpha = imgui.drag_float("Minimal Alpha", Config.MinimalAlpha, 0.01, 0, 1)
        configChanged = configChanged or changed
    end
    if Config.EnableAlpha or Config.EnableDistanceLimit then
        changed, Config.MaxDistance = imgui.drag_float("Max Distance", Config.MaxDistance, 0.1, 1, 10000)
        configChanged = configChanged or changed
    end

    changed, Config.EnableDistanceLimit = imgui.checkbox("Enable Distance Limit", Config.EnableDistanceLimit)
    configChanged = configChanged or changed

    changed, Config.SimpleMode = imgui.checkbox("Global Simple Mode", Config.SimpleMode)
    configChanged = configChanged or changed

    if Config.SimpleMode then
        changed, Config.Animal.Enable = imgui.checkbox("Enable Animal", Config.Animal.Enable)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, Config.Animal.HideDead = imgui.checkbox("Hide Dead Animal", Config.Animal.HideDead)
        configChanged = configChanged or changed

        changed, Config.Zako.Enable = imgui.checkbox("Enable Zako", Config.Zako.Enable)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, Config.Zako.HideDead = imgui.checkbox("Hide Dead Zako", Config.Zako.HideDead)
        configChanged = configChanged or changed

        changed, Config.Boss.Enable = imgui.checkbox("Enable Boss", Config.Boss.Enable)
        configChanged = configChanged or changed
        imgui.same_line()
        changed, Config.Boss.HideDead = imgui.checkbox("Hide Dead Boss", Config.Boss.HideDead)
        configChanged = configChanged or changed

        changed, Config.Width = imgui.drag_float("Width", Config.Width, 1, -w, w)
        configChanged = configChanged or changed
        changed, Config.Height = imgui.drag_float("Height", Config.Height, 1, -h, h)
        configChanged = configChanged or changed
        
        changed, Config.FontSize = imgui.slider_int("Font Size", Config.FontSize, 1, 40)
        configChanged = configChanged or changed
        Imgui.Tree("Colors", function ()
            changed, Config.FontColor = imgui.color_picker("Font Color", Config.FontColor)
            configChanged = configChanged or changed
            changed, Config.Color = imgui.color_picker("Color", Config.Color)
            configChanged = configChanged or changed
            changed, Config.BackgroundColor = imgui.color_picker("BackgroundColor", Config.BackgroundColor)
            configChanged = configChanged or changed
            changed, Config.OutlineColor = imgui.color_picker("OutlineColor", Config.OutlineColor)
            configChanged = configChanged or changed
        end)
    else
        imgui.text("Non-SimpleMode has worse performance than SimpleMode")
        changed, Config.Animal = EnemyTypeConfigMenu("Animal", Config.Animal)
        configChanged = configChanged or changed
        changed, Config.Zako = EnemyTypeConfigMenu("Zako", Config.Zako)
        configChanged = configChanged or changed
        changed, Config.Boss = EnemyTypeConfigMenu("Boss", Config.Boss)
        configChanged = configChanged or changed
    end

    if configChanged then
        mod.Config.ShowAllHpConfig = Config
    end

    return configChanged
end)

return Config
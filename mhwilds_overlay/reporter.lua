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

-- 
-- 锁、护锁回血，加护，锁刃刺击
-- 会心、会心【属性】、会心【特殊】
-- 斩味。伤口伤害

-- 属性、异常累积

-- -- 覆盖率：
-- 怨恨
-- 巧击
-- 攻击守势
-- 无伤
-- 逆袭
-- 拔刀术技
-- 抖擞
-- 属性变换
-- 钢刃
-- 挑战者
-- 力解
-- 火场怪力
-- 连击
-- 攻势
-- 因祸得福
-- 急袭
-- 无我之境
-- 属性吸收
-- 飞燕
-- 钻研


-- -- 攻击计数
-- 弱特
-- 会心率
-- 心眼
-- 钝器

-- 毒伤害强化？


-- -- 伤害增强、数值累积
-- 蓄力大师
-- 通常、贯通、散弹强化
-- 速射强化
-- 首发迅疾
-- 强四射击
-- 特射强化
-- 精灵加护
-- 锁刃刺击
-- 拔刀术力
-- 击晕术
-- 夺取耐力
-- 炮术